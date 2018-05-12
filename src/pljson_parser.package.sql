CREATE OR REPLACE PACKAGE pljson_parser AS
    /* scanner tokens:
      '{', '}', ',', ':', '[', ']', STRING, NUMBER, TRUE, FALSE, NULL
    */
    TYPE rtoken IS RECORD(
        type_name     VARCHAR2(7),
        line          PLS_INTEGER,
        col           PLS_INTEGER,
        data          VARCHAR2(32767),
        data_overflow CLOB); -- max_string_size

    TYPE ltokens IS TABLE OF rtoken INDEX BY PLS_INTEGER;
    TYPE json_src IS RECORD(
        len    NUMBER,
        offset NUMBER,
        src    VARCHAR2(32767),
        s_clob CLOB);

    json_strict BOOLEAN NOT NULL := FALSE;

    FUNCTION next_char
    (
        indx NUMBER,
        s    IN OUT NOCOPY json_src
    ) RETURN VARCHAR2;
    FUNCTION next_char2
    (
        indx   NUMBER,
        s      IN OUT NOCOPY json_src,
        amount NUMBER DEFAULT 1
    ) RETURN VARCHAR2;
    FUNCTION parseobj
    (
        tokens ltokens,
        indx   IN OUT NOCOPY PLS_INTEGER
    ) RETURN pljson;

    FUNCTION prepareclob(buf IN CLOB) RETURN pljson_parser.json_src;
    FUNCTION preparevarchar2(buf IN VARCHAR2) RETURN pljson_parser.json_src;
    FUNCTION lexer(jsrc IN OUT NOCOPY json_src) RETURN ltokens;
    PROCEDURE print_token(t rtoken);

    FUNCTION parser(str VARCHAR2) RETURN pljson;
    FUNCTION parse_list(str VARCHAR2) RETURN pljson_list;
    FUNCTION parse_any(str VARCHAR2) RETURN pljson_value;
    FUNCTION parser(str CLOB) RETURN pljson;
    FUNCTION parse_list(str CLOB) RETURN pljson_list;
    FUNCTION parse_any(str CLOB) RETURN pljson_value;
    PROCEDURE remove_duplicates(obj IN OUT NOCOPY pljson);

END pljson_parser;
/

CREATE OR REPLACE PACKAGE BODY pljson_parser AS

    decimalpoint VARCHAR2(1 CHAR) := '.';

    PROCEDURE update_decimalpoint AS
    BEGIN
        SELECT substr(VALUE, 1, 1)
          INTO decimalpoint
          FROM nls_session_parameters
         WHERE parameter = 'NLS_NUMERIC_CHARACTERS';
    END update_decimalpoint;

    /* type json_src is record (len number, offset number, src varchar2(32767), s_clob clob); */
    /* assertions
      offset: contains 0-base offset of buffer,
        so 1-st entry is offset + 1, 4000-th entry = offset + 4000
      src: contains offset + 1 .. offset + 4000, ex. 1..4000, 4001..8000, etc.
    */
    FUNCTION next_char
    (
        indx NUMBER,
        s    IN OUT NOCOPY json_src
    ) RETURN VARCHAR2 AS
    BEGIN
        IF (indx > s.len) THEN
            RETURN NULL;
        END IF;
        --right offset?
        /*  if(indx > 4000 + s.offset or indx < s.offset) then */
        /* fix for issue #37 */
        IF (indx > 4000 + s.offset OR indx <= s.offset) THEN
            --load right offset
            s.offset := indx - (indx MOD 4000);
            /* addon fix for issue #37 */
            IF s.offset = indx THEN
                s.offset := s.offset - 4000;
            END IF;
            s.src := dbms_lob.substr(s.s_clob, 4000, s.offset + 1);
        END IF;
        --read from s.src
        RETURN substr(s.src, indx - s.offset, 1);
    END;

    FUNCTION next_char2
    (
        indx   NUMBER,
        s      IN OUT NOCOPY json_src,
        amount NUMBER DEFAULT 1
    ) RETURN VARCHAR2 AS
        buf VARCHAR2(32767) := '';
    BEGIN
        FOR i IN 1 .. amount LOOP
            buf := buf || next_char(indx - 1 + i, s);
        END LOOP;
        RETURN buf;
    END;

    FUNCTION prepareclob(buf CLOB) RETURN pljson_parser.json_src AS
        temp pljson_parser.json_src;
    BEGIN
        temp.s_clob := buf;
        temp.offset := 0;
        temp.src    := dbms_lob.substr(buf, 4000, temp.offset + 1);
        temp.len    := dbms_lob.getlength(buf);
        RETURN temp;
    END;

    FUNCTION preparevarchar2(buf VARCHAR2) RETURN pljson_parser.json_src AS
        temp pljson_parser.json_src;
    BEGIN
        temp.s_clob := buf;
        temp.offset := 0;
        temp.src    := substr(buf, 1, 4000);
        temp.len    := length(buf);
        RETURN temp;
    END;

    PROCEDURE debug(text VARCHAR2) AS
    BEGIN
        dbms_output.put_line(text);
    END;

    PROCEDURE print_token(t rtoken) AS
    BEGIN
        dbms_output.put_line('Line: ' || t.line || ' - Column: ' || t.col ||
                             ' - Type: ' || t.type_name || ' - Content: ' ||
                             t.data);
    END print_token;

    /* SCANNER FUNCTIONS START */
    PROCEDURE s_error
    (
        text VARCHAR2,
        line NUMBER,
        col  NUMBER
    ) AS
    BEGIN
        raise_application_error(-20100,
                                'JSON Scanner exception @ line: ' || line ||
                                ' column: ' || col || ' - ' || text);
    END;

    PROCEDURE s_error
    (
        text VARCHAR2,
        tok  rtoken
    ) AS
    BEGIN
        raise_application_error(-20100,
                                'JSON Scanner exception @ line: ' ||
                                tok.line || ' column: ' || tok.col || ' - ' || text);
    END;

    FUNCTION mt
    (
        t VARCHAR2,
        l PLS_INTEGER,
        c PLS_INTEGER,
        d VARCHAR2
    ) RETURN rtoken AS
        token rtoken;
    BEGIN
        token.type_name := t;
        token.line      := l;
        token.col       := c;
        token.data      := d;
        RETURN token;
    END;

    FUNCTION lexnumber
    (
        jsrc IN OUT NOCOPY json_src,
        tok  IN OUT NOCOPY rtoken,
        indx IN OUT NOCOPY PLS_INTEGER
    ) RETURN PLS_INTEGER AS
        numbuf    VARCHAR2(4000) := '';
        buf       VARCHAR2(4);
        checkloop BOOLEAN;
    BEGIN
        buf := next_char(indx, jsrc);
        IF (buf = '-') THEN
            numbuf := '-';
            indx   := indx + 1;
        END IF;
        buf := next_char(indx, jsrc);
        --0 or [1-9]([0-9])*
        IF (buf = '0') THEN
            numbuf := numbuf || '0';
            indx   := indx + 1;
            buf    := next_char(indx, jsrc);
        ELSIF (buf >= '1' AND buf <= '9') THEN
            numbuf := numbuf || buf;
            indx   := indx + 1;
            --read digits
            buf := next_char(indx, jsrc);
            WHILE (buf >= '0' AND buf <= '9') LOOP
                numbuf := numbuf || buf;
                indx   := indx + 1;
                buf    := next_char(indx, jsrc);
            END LOOP;
        END IF;
        --fraction
        IF (buf = '.') THEN
            numbuf    := numbuf || buf;
            indx      := indx + 1;
            buf       := next_char(indx, jsrc);
            checkloop := FALSE;
            WHILE (buf >= '0' AND buf <= '9') LOOP
                checkloop := TRUE;
                numbuf    := numbuf || buf;
                indx      := indx + 1;
                buf       := next_char(indx, jsrc);
            END LOOP;
            IF (NOT checkloop) THEN
                s_error('Expected: digits in fraction', tok);
            END IF;
        END IF;
        --exp part
        IF (buf IN ('e', 'E')) THEN
            numbuf := numbuf || buf;
            indx   := indx + 1;
            buf    := next_char(indx, jsrc);
            IF (buf = '+' OR buf = '-') THEN
                numbuf := numbuf || buf;
                indx   := indx + 1;
                buf    := next_char(indx, jsrc);
            END IF;
            checkloop := FALSE;
            WHILE (buf >= '0' AND buf <= '9') LOOP
                checkloop := TRUE;
                numbuf    := numbuf || buf;
                indx      := indx + 1;
                buf       := next_char(indx, jsrc);
            END LOOP;
            IF (NOT checkloop) THEN
                s_error('Expected: digits in exp', tok);
            END IF;
        END IF;
    
        tok.data := numbuf;
        RETURN indx;
    END lexnumber;

    -- [a-zA-Z]([a-zA-Z0-9])*
    FUNCTION lexname
    (
        jsrc IN OUT NOCOPY json_src,
        tok  IN OUT NOCOPY rtoken,
        indx IN OUT NOCOPY PLS_INTEGER
    ) RETURN PLS_INTEGER AS
        varbuf VARCHAR2(32767) := '';
        buf    VARCHAR(4);
        num    NUMBER;
    BEGIN
        buf := next_char(indx, jsrc);
        WHILE (regexp_like(buf, '^[[:alnum:]\_]$', 'i')) LOOP
            varbuf := varbuf || buf;
            indx   := indx + 1;
            buf    := next_char(indx, jsrc);
            IF (buf IS NULL) THEN
                GOTO retname;
                --debug('Premature string ending');
            END IF;
        END LOOP;
        <<retname>>
    --could check for reserved keywords here
        --debug(varbuf);
        tok.data := varbuf;
        RETURN indx - 1;
    END lexname;

    PROCEDURE updateclob
    (
        v_extended IN OUT NOCOPY CLOB,
        v_str      VARCHAR2
    ) AS
    BEGIN
        dbms_lob.writeappend(v_extended, length(v_str), v_str);
    END updateclob;

    FUNCTION lexstring
    (
        jsrc    IN OUT NOCOPY json_src,
        tok     IN OUT NOCOPY rtoken,
        indx    IN OUT NOCOPY PLS_INTEGER,
        endchar CHAR
    ) RETURN PLS_INTEGER AS
        v_extended CLOB := NULL;
        v_count    NUMBER := 0;
        varbuf     VARCHAR2(32767) := '';
        buf        VARCHAR(4);
        wrong      BOOLEAN;
    BEGIN
        indx := indx + 1;
        buf  := next_char(indx, jsrc);
        WHILE (buf != endchar) LOOP
            --clob control
            IF (v_count > 8191) THEN
                --crazy oracle error (16383 is the highest working length with unistr - 8192 choosen to be safe)
                IF (v_extended IS NULL) THEN
                    v_extended := empty_clob();
                    dbms_lob.createtemporary(v_extended, TRUE);
                END IF;
                updateclob(v_extended, unistr(varbuf));
                varbuf  := '';
                v_count := 0;
            END IF;
            IF (buf = chr(13) OR buf = chr(9) OR buf = chr(10)) THEN
                s_error('Control characters not allowed (CHR(9),CHR(10)CHR(13))',
                        tok);
            END IF;
            IF (buf = '\') THEN
                --varbuf := varbuf || buf;
                indx := indx + 1;
                buf  := next_char(indx, jsrc);
                CASE
                    WHEN buf IN ('\') THEN
                        varbuf  := varbuf || buf || buf;
                        v_count := v_count + 2;
                        indx    := indx + 1;
                        buf     := next_char(indx, jsrc);
                    WHEN buf IN ('"', '/') THEN
                        varbuf  := varbuf || buf;
                        v_count := v_count + 1;
                        indx    := indx + 1;
                        buf     := next_char(indx, jsrc);
                    WHEN buf = '''' THEN
                        IF (json_strict = FALSE) THEN
                            varbuf  := varbuf || buf;
                            v_count := v_count + 1;
                            indx    := indx + 1;
                            buf     := next_char(indx, jsrc);
                        ELSE
                            s_error('strictmode - expected: " \ / b f n r t u ',
                                    tok);
                        END IF;
                    WHEN buf IN ('b', 'f', 'n', 'r', 't') THEN
                        --backspace b = U+0008
                        --formfeed  f = U+000C
                        --newline   n = U+000A
                        --carret    r = U+000D
                        --tabulator t = U+0009
                        CASE buf
                            WHEN 'b' THEN
                                varbuf := varbuf || chr(8);
                            WHEN 'f' THEN
                                varbuf := varbuf || chr(12);
                            WHEN 'n' THEN
                                varbuf := varbuf || chr(10);
                            WHEN 'r' THEN
                                varbuf := varbuf || chr(13);
                            WHEN 't' THEN
                                varbuf := varbuf || chr(9);
                        END CASE;
                        --varbuf := varbuf || buf;
                        v_count := v_count + 1;
                        indx    := indx + 1;
                        buf     := next_char(indx, jsrc);
                    WHEN buf = 'u' THEN
                        --four hexidecimal chars
                        DECLARE
                            four VARCHAR2(4);
                        BEGIN
                            four  := next_char2(indx + 1, jsrc, 4);
                            wrong := FALSE;
                            IF (upper(substr(four, 1, 1)) NOT IN
                               ('0',
                                 '1',
                                 '2',
                                 '3',
                                 '4',
                                 '5',
                                 '6',
                                 '7',
                                 '8',
                                 '9',
                                 'A',
                                 'B',
                                 'C',
                                 'D',
                                 'E',
                                 'F',
                                 'a',
                                 'b',
                                 'c',
                                 'd',
                                 'e',
                                 'f')) THEN
                                wrong := TRUE;
                            END IF;
                            IF (upper(substr(four, 2, 1)) NOT IN
                               ('0',
                                 '1',
                                 '2',
                                 '3',
                                 '4',
                                 '5',
                                 '6',
                                 '7',
                                 '8',
                                 '9',
                                 'A',
                                 'B',
                                 'C',
                                 'D',
                                 'E',
                                 'F',
                                 'a',
                                 'b',
                                 'c',
                                 'd',
                                 'e',
                                 'f')) THEN
                                wrong := TRUE;
                            END IF;
                            IF (upper(substr(four, 3, 1)) NOT IN
                               ('0',
                                 '1',
                                 '2',
                                 '3',
                                 '4',
                                 '5',
                                 '6',
                                 '7',
                                 '8',
                                 '9',
                                 'A',
                                 'B',
                                 'C',
                                 'D',
                                 'E',
                                 'F',
                                 'a',
                                 'b',
                                 'c',
                                 'd',
                                 'e',
                                 'f')) THEN
                                wrong := TRUE;
                            END IF;
                            IF (upper(substr(four, 4, 1)) NOT IN
                               ('0',
                                 '1',
                                 '2',
                                 '3',
                                 '4',
                                 '5',
                                 '6',
                                 '7',
                                 '8',
                                 '9',
                                 'A',
                                 'B',
                                 'C',
                                 'D',
                                 'E',
                                 'F',
                                 'a',
                                 'b',
                                 'c',
                                 'd',
                                 'e',
                                 'f')) THEN
                                wrong := TRUE;
                            END IF;
                            IF (wrong) THEN
                                s_error('expected: " \u([0-9][A-F]){4}',
                                        tok);
                            END IF;
                            --              varbuf := varbuf || buf || four;
                            varbuf  := varbuf || '\' || four; --chr(to_number(four,'XXXX'));
                            v_count := v_count + 5;
                            indx    := indx + 5;
                            buf     := next_char(indx, jsrc);
                        END;
                    ELSE
                        s_error('expected: " \ / b f n r t u ', tok);
                END CASE;
            ELSE
                varbuf  := varbuf || buf;
                v_count := v_count + 1;
                indx    := indx + 1;
                buf     := next_char(indx, jsrc);
            END IF;
        END LOOP;
    
        IF (buf IS NULL) THEN
            s_error('string ending not found', tok);
            --debug('Premature string ending');
        END IF;
    
        --debug(varbuf);
        --dbms_output.put_line(varbuf);
        IF (v_extended IS NOT NULL) THEN
            updateclob(v_extended, unistr(varbuf));
            tok.data_overflow := v_extended;
            tok.data          := dbms_lob.substr(v_extended, 1, 32767);
        ELSE
            tok.data := unistr(varbuf);
        END IF;
        RETURN indx;
    END lexstring;

    /* scanner tokens:
      '{', '}', ',', ':', '[', ']', STRING, NUMBER, TRUE, FALSE, NULL
    */
    FUNCTION lexer(jsrc IN OUT NOCOPY json_src) RETURN ltokens AS
        tokens   ltokens;
        indx     PLS_INTEGER := 1;
        tok_indx PLS_INTEGER := 1;
        buf      VARCHAR2(4);
        lin_no   NUMBER := 1;
        col_no   NUMBER := 0;
    BEGIN
        WHILE (indx <= jsrc.len) LOOP
            --read into buf
            buf    := next_char(indx, jsrc);
            col_no := col_no + 1;
            --convert to switch case
            CASE
                WHEN buf = '{' THEN
                    tokens(tok_indx) := mt('{', lin_no, col_no, NULL);
                    tok_indx := tok_indx + 1;
                WHEN buf = '}' THEN
                    tokens(tok_indx) := mt('}', lin_no, col_no, NULL);
                    tok_indx := tok_indx + 1;
                WHEN buf = ',' THEN
                    tokens(tok_indx) := mt(',', lin_no, col_no, NULL);
                    tok_indx := tok_indx + 1;
                WHEN buf = ':' THEN
                    tokens(tok_indx) := mt(':', lin_no, col_no, NULL);
                    tok_indx := tok_indx + 1;
                WHEN buf = '[' THEN
                    tokens(tok_indx) := mt('[', lin_no, col_no, NULL);
                    tok_indx := tok_indx + 1;
                WHEN buf = ']' THEN
                    tokens(tok_indx) := mt(']', lin_no, col_no, NULL);
                    tok_indx := tok_indx + 1;
                WHEN buf = 't' THEN
                    IF (next_char2(indx, jsrc, 4) != 'true') THEN
                        IF (json_strict = FALSE AND
                           regexp_like(buf, '^[[:alpha:]]$', 'i')) THEN
                            tokens(tok_indx) := mt('STRING',
                                                   lin_no,
                                                   col_no,
                                                   NULL);
                            indx := lexname(jsrc, tokens(tok_indx), indx);
                            col_no := col_no +
                                      length(tokens(tok_indx).data) + 1;
                            tok_indx := tok_indx + 1;
                        ELSE
                            s_error('Expected: ''true''', lin_no, col_no);
                        END IF;
                    ELSE
                        tokens(tok_indx) := mt('TRUE', lin_no, col_no, NULL);
                        tok_indx := tok_indx + 1;
                        indx := indx + 3;
                        col_no := col_no + 3;
                    END IF;
                WHEN buf = 'n' THEN
                    IF (next_char2(indx, jsrc, 4) != 'null') THEN
                        IF (json_strict = FALSE AND
                           regexp_like(buf, '^[[:alpha:]]$', 'i')) THEN
                            tokens(tok_indx) := mt('STRING',
                                                   lin_no,
                                                   col_no,
                                                   NULL);
                            indx := lexname(jsrc, tokens(tok_indx), indx);
                            col_no := col_no +
                                      length(tokens(tok_indx).data) + 1;
                            tok_indx := tok_indx + 1;
                        ELSE
                            s_error('Expected: ''null''', lin_no, col_no);
                        END IF;
                    ELSE
                        tokens(tok_indx) := mt('NULL', lin_no, col_no, NULL);
                        tok_indx := tok_indx + 1;
                        indx := indx + 3;
                        col_no := col_no + 3;
                    END IF;
                WHEN buf = 'f' THEN
                    IF (next_char2(indx, jsrc, 5) != 'false') THEN
                        IF (json_strict = FALSE AND
                           regexp_like(buf, '^[[:alpha:]]$', 'i')) THEN
                            tokens(tok_indx) := mt('STRING',
                                                   lin_no,
                                                   col_no,
                                                   NULL);
                            indx := lexname(jsrc, tokens(tok_indx), indx);
                            col_no := col_no +
                                      length(tokens(tok_indx).data) + 1;
                            tok_indx := tok_indx + 1;
                        ELSE
                            s_error('Expected: ''false''', lin_no, col_no);
                        END IF;
                    ELSE
                        tokens(tok_indx) := mt('FALSE',
                                               lin_no,
                                               col_no,
                                               NULL);
                        tok_indx := tok_indx + 1;
                        indx := indx + 4;
                        col_no := col_no + 4;
                    END IF;
                    /* -- 9 = TAB, 10 = \n, 13 = \r (Linux = \n, Windows = \r\n, Mac = \r */
                WHEN (buf = chr(10)) THEN
                    --linux newlines
                    lin_no := lin_no + 1;
                    col_no := 0;
                
                WHEN (buf = chr(13)) THEN
                    --Windows or Mac way
                    lin_no := lin_no + 1;
                    col_no := 0;
                    IF (jsrc.len >= indx + 1) THEN
                        -- better safe than sorry
                        buf := next_char(indx + 1, jsrc);
                        IF (buf = chr(10)) THEN
                            --\r\n
                            indx := indx + 1;
                        END IF;
                    END IF;
                
                WHEN (buf = chr(9)) THEN
                    NULL; --tabbing
                WHEN (buf IN ('-',
                              '0',
                              '1',
                              '2',
                              '3',
                              '4',
                              '5',
                              '6',
                              '7',
                              '8',
                              '9')) THEN
                    --number
                    tokens(tok_indx) := mt('NUMBER', lin_no, col_no, NULL);
                    indx := lexnumber(jsrc, tokens(tok_indx), indx) - 1;
                    col_no := col_no + length(tokens(tok_indx).data);
                    tok_indx := tok_indx + 1;
                WHEN buf = '"' THEN
                    --number
                    tokens(tok_indx) := mt('STRING', lin_no, col_no, NULL);
                    indx := lexstring(jsrc, tokens(tok_indx), indx, '"');
                    col_no := col_no + length(tokens(tok_indx).data) + 1;
                    tok_indx := tok_indx + 1;
                WHEN buf = '''' AND json_strict = FALSE THEN
                    --number
                    tokens(tok_indx) := mt('STRING', lin_no, col_no, NULL);
                    indx := lexstring(jsrc, tokens(tok_indx), indx, '''');
                    col_no := col_no + length(tokens(tok_indx).data) + 1; --hovsa her
                    tok_indx := tok_indx + 1;
                WHEN json_strict = FALSE AND
                     regexp_like(buf, '^[[:alpha:]]$', 'i') THEN
                    tokens(tok_indx) := mt('STRING', lin_no, col_no, NULL);
                    indx := lexname(jsrc, tokens(tok_indx), indx);
                    IF (tokens(tok_indx).data_overflow IS NOT NULL) THEN
                        col_no := col_no +
                                  dbms_lob.getlength(tokens(tok_indx)
                                                     .data_overflow) + 1;
                    ELSE
                        col_no := col_no + length(tokens(tok_indx).data) + 1;
                    END IF;
                    tok_indx := tok_indx + 1;
                WHEN json_strict = FALSE AND
                     buf || next_char(indx + 1, jsrc) = '/*' THEN
                    --strip comments
                    DECLARE
                        saveindx NUMBER := indx;
                        un_esc   CLOB;
                    BEGIN
                        indx := indx + 1;
                        LOOP
                            indx := indx + 1;
                            buf  := next_char(indx, jsrc) ||
                                    next_char(indx + 1, jsrc);
                            EXIT WHEN buf = '*/';
                            EXIT WHEN buf IS NULL;
                        END LOOP;
                    
                        IF (indx = saveindx + 2) THEN
                            --enter unescaped mode
                            --dbms_output.put_line('Entering unescaped mode');
                            un_esc := empty_clob();
                            dbms_lob.createtemporary(un_esc, TRUE);
                            indx := indx + 1;
                            LOOP
                                indx := indx + 1;
                                buf  := next_char(indx, jsrc) ||
                                        next_char(indx + 1, jsrc) ||
                                        next_char(indx + 2, jsrc) ||
                                        next_char(indx + 3, jsrc);
                                EXIT WHEN buf = '/**/';
                                IF buf IS NULL THEN
                                    s_error('Unexpected sequence /**/ to end unescaped data: ' || buf,
                                            lin_no,
                                            col_no);
                                END IF;
                                buf := next_char(indx, jsrc);
                                dbms_lob.writeappend(un_esc,
                                                     length(buf),
                                                     buf);
                            END LOOP;
                            tokens(tok_indx) := mt('ESTRING',
                                                   lin_no,
                                                   col_no,
                                                   NULL);
                            tokens(tok_indx).data_overflow := un_esc;
                            col_no := col_no + dbms_lob.getlength(un_esc) + 1; --note: line count won't work properly
                            tok_indx := tok_indx + 1;
                            indx := indx + 2;
                        END IF;
                    
                        indx := indx + 1;
                    END;
                WHEN buf = ' ' THEN
                    NULL; --space
                ELSE
                    s_error('Unexpected char: ' || buf, lin_no, col_no);
            END CASE;
        
            indx := indx + 1;
        END LOOP;
    
        RETURN tokens;
    END lexer;

    /* SCANNER END */

    /* PARSER FUNCTIONS START */
    PROCEDURE p_error
    (
        text VARCHAR2,
        tok  rtoken
    ) AS
    BEGIN
        raise_application_error(-20101,
                                'JSON Parser exception @ line: ' ||
                                tok.line || ' column: ' || tok.col || ' - ' || text);
    END;

    FUNCTION parsearr
    (
        tokens ltokens,
        indx   IN OUT NOCOPY PLS_INTEGER
    ) RETURN pljson_list AS
        e_arr    pljson_value_array := pljson_value_array();
        ret_list pljson_list := pljson_list();
        v_count  NUMBER := 0;
        tok      rtoken;
        pv       pljson_value;
    BEGIN
        --value, value, value ]
        IF (indx > tokens.count) THEN
            p_error('more elements in array was excepted', tok);
        END IF;
        tok := tokens(indx);
        WHILE (tok.type_name != ']') LOOP
            e_arr.extend;
            v_count := v_count + 1;
            CASE tok.type_name
                WHEN 'TRUE' THEN
                    e_arr(v_count) := pljson_value(TRUE);
                WHEN 'FALSE' THEN
                    e_arr(v_count) := pljson_value(FALSE);
                WHEN 'NULL' THEN
                    e_arr(v_count) := pljson_value;
                WHEN 'STRING' THEN
                    e_arr(v_count) := CASE
                                          WHEN tok.data_overflow IS NOT NULL THEN
                                           pljson_value(tok.data_overflow)
                                          ELSE
                                           pljson_value(tok.data)
                                      END;
                WHEN 'ESTRING' THEN
                    e_arr(v_count) := pljson_value(tok.data_overflow, FALSE);
                    /* E.I.Sarmas (github.com/dsnz)   2016-12-01   support for binary_double numbers */
            --when 'NUMBER' then e_arr(v_count) := pljson_value(to_number(replace(tok.data, '.', decimalpoint)));
                WHEN 'NUMBER' THEN
                    pv := pljson_value(0);
                    pv.parse_number(REPLACE(tok.data, '.', decimalpoint));
                    e_arr(v_count) := pv;
                WHEN '[' THEN
                    DECLARE
                        e_list pljson_list;
                    BEGIN
                        indx := indx + 1;
                        e_list := parsearr(tokens, indx);
                        e_arr(v_count) := e_list.to_json_value;
                    END;
                WHEN '{' THEN
                    indx := indx + 1;
                    e_arr(v_count) := parseobj(tokens, indx).to_json_value;
                ELSE
                    p_error('Expected a value', tok);
            END CASE;
            indx := indx + 1;
            IF (indx > tokens.count) THEN
                p_error('] not found', tok);
            END IF;
            tok := tokens(indx);
            IF (tok.type_name = ',') THEN
                --advance
                indx := indx + 1;
                IF (indx > tokens.count) THEN
                    p_error('more elements in array was excepted', tok);
                END IF;
                tok := tokens(indx);
                IF (tok.type_name = ']') THEN
                    --premature exit
                    p_error('Premature exit in array', tok);
                END IF;
            ELSIF (tok.type_name != ']') THEN
                --error
                p_error('Expected , or ]', tok);
            END IF;
        
        END LOOP;
        ret_list.list_data := e_arr;
        RETURN ret_list;
    END parsearr;

    FUNCTION parsemem
    (
        tokens   ltokens,
        indx     IN OUT PLS_INTEGER,
        mem_name VARCHAR2,
        mem_indx NUMBER
    ) RETURN pljson_value AS
        mem pljson_value;
        tok rtoken;
        pv  pljson_value;
    BEGIN
        tok := tokens(indx);
        CASE tok.type_name
            WHEN 'TRUE' THEN
                mem := pljson_value(TRUE);
            WHEN 'FALSE' THEN
                mem := pljson_value(FALSE);
            WHEN 'NULL' THEN
                mem := pljson_value;
            WHEN 'STRING' THEN
                mem := CASE
                           WHEN tok.data_overflow IS NOT NULL THEN
                            pljson_value(tok.data_overflow)
                           ELSE
                            pljson_value(tok.data)
                       END;
            WHEN 'ESTRING' THEN
                mem := pljson_value(tok.data_overflow, FALSE);
                /* E.I.Sarmas (github.com/dsnz)   2016-12-01   support for binary_double numbers */
        --when 'NUMBER' then mem := pljson_value(to_number(replace(tok.data, '.', decimalpoint)));
            WHEN 'NUMBER' THEN
                pv := pljson_value(0);
                pv.parse_number(REPLACE(tok.data, '.', decimalpoint));
                mem := pv;
            WHEN '[' THEN
                DECLARE
                    e_list pljson_list;
                BEGIN
                    indx   := indx + 1;
                    e_list := parsearr(tokens, indx);
                    mem    := e_list.to_json_value;
                END;
            WHEN '{' THEN
                indx := indx + 1;
                mem  := parseobj(tokens, indx).to_json_value;
            ELSE
                p_error('Found ' || tok.type_name, tok);
        END CASE;
        mem.mapname := mem_name;
        mem.mapindx := mem_indx;
    
        indx := indx + 1;
        RETURN mem;
    END parsemem;

    /*procedure test_duplicate_members(arr in json_member_array, mem_name in varchar2, wheretok rToken) as
    begin
      for i in 1 .. arr.count loop
        if(arr(i).member_name = mem_name) then
          p_error('Duplicate member name', wheretok);
        end if;
      end loop;
    end test_duplicate_members;*/

    FUNCTION parseobj
    (
        tokens ltokens,
        indx   IN OUT NOCOPY PLS_INTEGER
    ) RETURN pljson AS
        TYPE memmap IS TABLE OF NUMBER INDEX BY VARCHAR2(4000); -- i've read somewhere that this is not possible - but it is!
        mymap         memmap;
        nullelemfound BOOLEAN := FALSE;
    
        obj      pljson;
        tok      rtoken;
        mem_name VARCHAR(4000);
        arr      pljson_value_array := pljson_value_array();
    BEGIN
        --what to expect?
        WHILE (indx <= tokens.count) LOOP
            tok := tokens(indx);
            --debug('E: '||tok.type_name);
            CASE tok.type_name
                WHEN 'STRING' THEN
                    --member
                    mem_name := substr(tok.data, 1, 4000);
                    BEGIN
                        IF (mem_name IS NULL) THEN
                            IF (nullelemfound) THEN
                                p_error('Duplicate empty member: ', tok);
                            ELSE
                                nullelemfound := TRUE;
                            END IF;
                        ELSIF (mymap(mem_name) IS NOT NULL) THEN
                            p_error('Duplicate member name: ' || mem_name,
                                    tok);
                        END IF;
                    EXCEPTION
                        WHEN no_data_found THEN
                            mymap(mem_name) := 1;
                    END;
                
                    indx := indx + 1;
                    IF (indx > tokens.count) THEN
                        p_error('Unexpected end of input', tok);
                    END IF;
                    tok  := tokens(indx);
                    indx := indx + 1;
                    IF (indx > tokens.count) THEN
                        p_error('Unexpected end of input', tok);
                    END IF;
                    IF (tok.type_name = ':') THEN
                        --parse
                        DECLARE
                            jmb pljson_value;
                            x   NUMBER;
                        BEGIN
                            x   := arr.count + 1;
                            jmb := parsemem(tokens, indx, mem_name, x);
                            arr.extend;
                            arr(x) := jmb;
                        END;
                    ELSE
                        p_error('Expected '':''', tok);
                    END IF;
                    --move indx forward if ',' is found
                    IF (indx > tokens.count) THEN
                        p_error('Unexpected end of input', tok);
                    END IF;
                
                    tok := tokens(indx);
                    IF (tok.type_name = ',') THEN
                        --debug('found ,');
                        indx := indx + 1;
                        tok  := tokens(indx);
                        IF (tok.type_name = '}') THEN
                            --premature exit
                            p_error('Premature exit in json object', tok);
                        END IF;
                    ELSIF (tok.type_name != '}') THEN
                        p_error('A comma seperator is probably missing',
                                tok);
                    END IF;
                WHEN '}' THEN
                    obj           := pljson();
                    obj.json_data := arr;
                    RETURN obj;
                ELSE
                    p_error('Expected string or }', tok);
            END CASE;
        END LOOP;
    
        p_error('} not found', tokens(indx - 1));
    
        RETURN obj;
    
    END;

    FUNCTION parser(str VARCHAR2) RETURN pljson AS
        tokens ltokens;
        obj    pljson;
        indx   PLS_INTEGER := 1;
        jsrc   json_src;
    BEGIN
        update_decimalpoint();
        jsrc   := preparevarchar2(str);
        tokens := lexer(jsrc);
        IF (tokens(indx).type_name = '{') THEN
            indx := indx + 1;
            obj  := parseobj(tokens, indx);
        ELSE
            raise_application_error(-20101,
                                    'JSON Parser exception - no { start found');
        END IF;
        IF (tokens.count != indx) THEN
            p_error('} should end the JSON object', tokens(indx));
        END IF;
    
        RETURN obj;
    END parser;

    FUNCTION parse_list(str VARCHAR2) RETURN pljson_list AS
        tokens ltokens;
        obj    pljson_list;
        indx   PLS_INTEGER := 1;
        jsrc   json_src;
    BEGIN
        update_decimalpoint();
        jsrc   := preparevarchar2(str);
        tokens := lexer(jsrc);
        IF (tokens(indx).type_name = '[') THEN
            indx := indx + 1;
            obj  := parsearr(tokens, indx);
        ELSE
            raise_application_error(-20101,
                                    'JSON List Parser exception - no [ start found');
        END IF;
        IF (tokens.count != indx) THEN
            p_error('] should end the JSON List object', tokens(indx));
        END IF;
    
        RETURN obj;
    END parse_list;

    FUNCTION parse_list(str CLOB) RETURN pljson_list AS
        tokens ltokens;
        obj    pljson_list;
        indx   PLS_INTEGER := 1;
        jsrc   json_src;
    BEGIN
        update_decimalpoint();
        jsrc   := prepareclob(str);
        tokens := lexer(jsrc);
        IF (tokens(indx).type_name = '[') THEN
            indx := indx + 1;
            obj  := parsearr(tokens, indx);
        ELSE
            raise_application_error(-20101,
                                    'JSON List Parser exception - no [ start found');
        END IF;
        IF (tokens.count != indx) THEN
            p_error('] should end the JSON List object', tokens(indx));
        END IF;
    
        RETURN obj;
    END parse_list;

    FUNCTION parser(str CLOB) RETURN pljson AS
        tokens ltokens;
        obj    pljson;
        indx   PLS_INTEGER := 1;
        jsrc   json_src;
    BEGIN
        update_decimalpoint();
        --dbms_output.put_line('Using clob');
        jsrc   := prepareclob(str);
        tokens := lexer(jsrc);
        IF (tokens(indx).type_name = '{') THEN
            indx := indx + 1;
            obj  := parseobj(tokens, indx);
        ELSE
            raise_application_error(-20101,
                                    'JSON Parser exception - no { start found');
        END IF;
        IF (tokens.count != indx) THEN
            p_error('} should end the JSON object', tokens(indx));
        END IF;
    
        RETURN obj;
    END parser;

    FUNCTION parse_any(str VARCHAR2) RETURN pljson_value AS
        tokens ltokens;
        obj    pljson_list;
        ret    pljson_value;
        indx   PLS_INTEGER := 1;
        jsrc   json_src;
    BEGIN
        update_decimalpoint();
        jsrc := preparevarchar2(str);
        tokens := lexer(jsrc);
        tokens(tokens.count + 1).type_name := ']';
        obj := parsearr(tokens, indx);
        IF (tokens.count != indx) THEN
            p_error('] should end the JSON List object', tokens(indx));
        END IF;
    
        RETURN obj.head();
    END parse_any;

    FUNCTION parse_any(str CLOB) RETURN pljson_value AS
        tokens ltokens;
        obj    pljson_list;
        indx   PLS_INTEGER := 1;
        jsrc   json_src;
    BEGIN
        update_decimalpoint();
        jsrc := prepareclob(str);
        tokens := lexer(jsrc);
        tokens(tokens.count + 1).type_name := ']';
        obj := parsearr(tokens, indx);
        IF (tokens.count != indx) THEN
            p_error('] should end the JSON List object', tokens(indx));
        END IF;
    
        RETURN obj.head();
    END parse_any;

    /* last entry is the one to keep */
    PROCEDURE remove_duplicates(obj IN OUT NOCOPY pljson) AS
        TYPE memberlist IS TABLE OF pljson_value INDEX BY VARCHAR2(4000);
        members       memberlist;
        nulljsonvalue pljson_value := NULL;
        validated     pljson := pljson();
        indx          VARCHAR2(4000);
    BEGIN
        FOR i IN 1 .. obj.count LOOP
            IF (obj.get(i).mapname IS NULL) THEN
                nulljsonvalue := obj.get(i);
            ELSE
                members(obj.get(i).mapname) := obj.get(i);
            END IF;
        END LOOP;
    
        validated.check_duplicate(FALSE);
        indx := members.first;
        LOOP
            EXIT WHEN indx IS NULL;
            validated.put(indx, members(indx));
            indx := members.next(indx);
        END LOOP;
        IF (nulljsonvalue IS NOT NULL) THEN
            validated.put('', nulljsonvalue);
        END IF;
    
        validated.check_for_duplicate := obj.check_for_duplicate;
    
        obj := validated;
    END;

END pljson_parser;
/
