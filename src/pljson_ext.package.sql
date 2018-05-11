create or replace package pljson_ext as
  /**
   * <p>This package contains the path implementation and adds support for dates
   * and binary lob's. Dates are not a part of the JSON standard, so it's up to
   * you to specify how you would like to handle dates. The
   * current implementation specifies a date to be a string which follows the
   * format: <code>yyyy-mm-dd hh24:mi:ss</code>. If your needs differ from this,
   * then you must rewrite the functions in the implementation.</p>
   *
   * @headercom
   */

  /* This package contains extra methods to lookup types and
     an easy way of adding date values in json - without changing the structure */
  function parsePath(json_path varchar2, base number default 1) return pljson_list;

  --JSON Path getters
  function get_json_value(obj pljson, v_path varchar2, base number default 1) return pljson_value;
  function get_string(obj pljson, path varchar2,       base number default 1) return varchar2;
  function get_number(obj pljson, path varchar2,       base number default 1) return number;
  function get_double(obj pljson, path varchar2,       base number default 1) return binary_double;
  function get_json(obj pljson, path varchar2,         base number default 1) return pljson;
  function get_json_list(obj pljson, path varchar2,    base number default 1) return pljson_list;
  function get_bool(obj pljson, path varchar2,         base number default 1) return boolean;

  --JSON Path putters
  procedure put(obj in out nocopy pljson, path varchar2, elem varchar2,   base number default 1);
  procedure put(obj in out nocopy pljson, path varchar2, elem number,     base number default 1);
  procedure put(obj in out nocopy pljson, path varchar2, elem binary_double, base number default 1);
  procedure put(obj in out nocopy pljson, path varchar2, elem pljson,       base number default 1);
  procedure put(obj in out nocopy pljson, path varchar2, elem pljson_list,  base number default 1);
  procedure put(obj in out nocopy pljson, path varchar2, elem boolean,    base number default 1);
  procedure put(obj in out nocopy pljson, path varchar2, elem pljson_value, base number default 1);

  procedure remove(obj in out nocopy pljson, path varchar2, base number default 1);

  --Pretty print with JSON Path - obsolete in 0.9.4 - obj.path(v_path).(to_char,print,htp)
  function pp(obj pljson, v_path varchar2) return varchar2;
  procedure pp(obj pljson, v_path varchar2); --using dbms_output.put_line
  procedure pp_htp(obj pljson, v_path varchar2); --using htp.print

  --extra function checks if number has no fraction
  function is_integer(v pljson_value) return boolean;

  format_string varchar2(30 char) := 'yyyy-mm-dd hh24:mi:ss';
  --extension enables json to store dates without compromising the implementation
  function to_json_value(d date) return pljson_value;
  --notice that a date type in json is also a varchar2
  function is_date(v pljson_value) return boolean;
  --conversion is needed to extract dates
  function to_date(v pljson_value) return date;
  --JSON Path with date
  function get_date(obj pljson, path varchar2, base number default 1) return date;
  procedure put(obj in out nocopy pljson, path varchar2, elem date, base number default 1);

  /*
    encoding in lines of 64 chars ending with CR+NL
  */
  function encodeBase64Blob2Clob(p_blob in  blob) return clob;
  /*
    assumes single base64 string or broken into equal length lines of max 64 or 76 chars
    (as specified by RFC-1421 or RFC-2045)
    line ending can be CR+NL or NL
  */
  function decodeBase64Clob2Blob(p_clob clob) return blob;

  function base64(binarydata blob) return pljson_list;
  function base64(l pljson_list) return blob;

  function encode(binarydata blob) return pljson_value;
  function decode(v pljson_value) return blob;


  
  function clob2blob(
    p_clob in clob)
    return blob;

  function blob2clob(
    p_blob in blob,
    p_blob_csid in integer default dbms_lob.default_csid)
    return clob;
end pljson_ext;
/


CREATE OR REPLACE PACKAGE BODY pljson_ext AS

    scanner_exception EXCEPTION;
    PRAGMA EXCEPTION_INIT(scanner_exception, -20100);
    parser_exception EXCEPTION;
    PRAGMA EXCEPTION_INIT(parser_exception, -20101);
    jext_exception EXCEPTION;
    PRAGMA EXCEPTION_INIT(jext_exception, -20110);

    PROCEDURE assert
    (
        p_condition IN BOOLEAN,
        p_msg       IN VARCHAR2
    ) AS
    BEGIN
        IF NOT p_condition OR p_condition IS NULL THEN
            raise_application_error(-20000, p_msg);
        END IF;
    END assert;

    FUNCTION is_integer(v pljson_value) RETURN BOOLEAN AS
        num        NUMBER;
        num_double binary_double;
        int_number NUMBER(38); --the oracle way to specify an integer
        int_double binary_double; --the oracle way to specify an integer
    BEGIN
        IF (v.is_number_repr_number) THEN
            num        := v.get_number;
            int_number := trunc(num);
            RETURN(int_number = num); --no rounding errors?
        ELSIF (v.is_number_repr_double) THEN
            num_double := v.get_double;
            int_double := trunc(num_double);
            RETURN(int_double = num_double); --no rounding errors?
        ELSE
            RETURN FALSE;
        END IF;
    END;

    --extension enables json to store dates without compromising the implementation
    FUNCTION to_json_value(d DATE) RETURN pljson_value AS
    BEGIN
        RETURN pljson_value(to_char(d, format_string));
    END;

    --notice that a date type in json is also a varchar2
    FUNCTION is_date(v pljson_value) RETURN BOOLEAN AS
        temp DATE;
    BEGIN
        temp := pljson_ext.to_date(v);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN FALSE;
    END;

    --conversion is needed to extract dates
    FUNCTION to_date(v pljson_value) RETURN DATE AS
    BEGIN
        IF (v.is_string) THEN
            RETURN standard.to_date(v.get_string, format_string);
        ELSE
            raise_application_error(-20110,
                                    'Anydata did not contain a date-value');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            raise_application_error(-20110,
                                    'Anydata did not contain a date on the format: ' ||
                                    format_string);
    END;

    /*
      assumes single base64 string or broken into equal length lines of max 64 or 76 chars
      (as specified by RFC-1421 or RFC-2045)
      line ending can be CR+NL or NL
    */
    FUNCTION decodebase64clob2blob(p_clob CLOB) RETURN BLOB IS
        r_blob      BLOB;
        clob_size   NUMBER;
        pos         NUMBER;
        c_buf       VARCHAR2(32767);
        r_buf       RAW(32767);
        v_read_size NUMBER;
        v_line_size NUMBER;
    BEGIN
        dbms_lob.createtemporary(r_blob, TRUE, dbms_lob.call);
    
        v_line_size := 64;
        IF dbms_lob.substr(p_clob, 1, 65) = chr(10) THEN
            v_line_size := 65;
        END IF;
        IF dbms_lob.substr(p_clob, 1, 65) = chr(13) THEN
            v_line_size := 66;
        END IF;
        IF dbms_lob.substr(p_clob, 1, 77) = chr(10) THEN
            v_line_size := 77;
        END IF;
        IF dbms_lob.substr(p_clob, 1, 77) = chr(13) THEN
            v_line_size := 78;
        END IF;
        v_read_size := floor(32767 / v_line_size) * v_line_size;
        clob_size   := dbms_lob.getlength(p_clob);
        pos         := 1;
        WHILE (pos < clob_size) LOOP
            dbms_lob.read(p_clob, v_read_size, pos, c_buf);
            r_buf := utl_encode.base64_decode(utl_raw.cast_to_raw(c_buf));
            dbms_lob.writeappend(r_blob, utl_raw.length(r_buf), r_buf);
            pos := pos + v_read_size;
        END LOOP;
        RETURN r_blob;
    END decodebase64clob2blob;

    /*
      encoding in lines of 64 chars ending with CR+NL or NL
      there is automatic detection of proper line ending as done by utl_encode package
    */
    FUNCTION encodebase64blob2clob(p_blob IN BLOB) RETURN CLOB IS
        r_clob CLOB;
        c_step PLS_INTEGER := 12000;
        c_buf  VARCHAR2(32767);
    BEGIN
        IF p_blob IS NOT NULL THEN
            dbms_lob.createtemporary(r_clob, FALSE, dbms_lob.call);
            FOR i IN 0 .. trunc((dbms_lob.getlength(p_blob) - 1) / c_step) LOOP
                c_buf := utl_raw.cast_to_varchar2(utl_encode.base64_encode(dbms_lob.substr(p_blob,
                                                                                           c_step,
                                                                                           i *
                                                                                           c_step + 1)));
            
                IF substr(c_buf, 65, 1) = chr(10) THEN
                    c_buf := c_buf || chr(10);
                END IF;
                IF substr(c_buf, 65, 1) = chr(13) THEN
                    c_buf := c_buf || chr(13) || chr(10);
                END IF;
                dbms_lob.writeappend(lob_loc => r_clob,
                                     amount  => length(c_buf),
                                     buffer  => c_buf);
            END LOOP;
        END IF;
        RETURN r_clob;
    END encodebase64blob2clob;

    --Json Path parser
    FUNCTION parsepath
    (
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) RETURN pljson_list AS
        build_path VARCHAR2(32767) := '[';
        buf        VARCHAR2(4);
        endstring  VARCHAR2(1);
        indx       NUMBER := 1;
        ret        pljson_list;
    
        PROCEDURE next_char AS
        BEGIN
            IF (indx <= length(json_path)) THEN
                buf  := substr(json_path, indx, 1);
                indx := indx + 1;
            ELSE
                buf := NULL;
            END IF;
        END;
        --skip ws
        PROCEDURE skipws AS
        BEGIN
            WHILE (buf IN (chr(9), chr(10), chr(13), ' ')) LOOP
                next_char;
            END LOOP;
        END;
    
    BEGIN
        next_char();
        WHILE (buf IS NOT NULL) LOOP
            IF (buf = '.') THEN
                next_char();
                IF (buf IS NULL) THEN
                    raise_application_error(-20110,
                                            'JSON Path parse error: . is not a valid json_path end');
                END IF;
                IF (NOT regexp_like(buf, '^[[:alnum:]\_ ]+', 'c')) THEN
                    raise_application_error(-20110,
                                            'JSON Path parse error: alpha-numeric character or space expected at position ' || indx);
                END IF;
            
                IF (build_path != '[') THEN
                    build_path := build_path || ',';
                END IF;
                build_path := build_path || '"';
                WHILE (regexp_like(buf, '^[[:alnum:]\_ ]+', 'c')) LOOP
                    build_path := build_path || buf;
                    next_char();
                END LOOP;
                build_path := build_path || '"';
            ELSIF (buf = '[') THEN
                next_char();
                skipws();
                IF (buf IS NULL) THEN
                    raise_application_error(-20110,
                                            'JSON Path parse error: [ is not a valid json_path end');
                END IF;
                IF (buf IN ('1', '2', '3', '4', '5', '6', '7', '8', '9') OR
                   (buf = '0' AND base = 0)) THEN
                    IF (build_path != '[') THEN
                        build_path := build_path || ',';
                    END IF;
                    WHILE (buf IN ('0',
                                   '1',
                                   '2',
                                   '3',
                                   '4',
                                   '5',
                                   '6',
                                   '7',
                                   '8',
                                   '9')) LOOP
                        build_path := build_path || buf;
                        next_char();
                    END LOOP;
                ELSIF (regexp_like(buf, '^(\"|\'')', 'c')) THEN
                    endstring := buf;
                    IF (build_path != '[') THEN
                        build_path := build_path || ',';
                    END IF;
                    build_path := build_path || '"';
                    next_char();
                    IF (buf IS NULL) THEN
                        raise_application_error(-20110,
                                                'JSON Path parse error: premature json_path end');
                    END IF;
                    WHILE (buf != endstring) LOOP
                        build_path := build_path || buf;
                        next_char();
                        IF (buf IS NULL) THEN
                            raise_application_error(-20110,
                                                    'JSON Path parse error: premature json_path end');
                        END IF;
                        IF (buf = '\') THEN
                            next_char();
                            build_path := build_path || '\' || buf;
                            next_char();
                        END IF;
                    END LOOP;
                    build_path := build_path || '"';
                    next_char();
                ELSE
                    raise_application_error(-20110,
                                            'JSON Path parse error: expected a string or an positive integer at ' || indx);
                END IF;
                skipws();
                IF (buf IS NULL) THEN
                    raise_application_error(-20110,
                                            'JSON Path parse error: premature json_path end');
                END IF;
                IF (buf != ']') THEN
                    raise_application_error(-20110,
                                            'JSON Path parse error: no array ending found. found: ' || buf);
                END IF;
                next_char();
                skipws();
            ELSIF (build_path = '[') THEN
                IF (NOT regexp_like(buf, '^[[:alnum:]\_ ]+', 'c')) THEN
                    raise_application_error(-20110,
                                            'JSON Path parse error: alpha-numeric character or space expected at position ' || indx);
                END IF;
                build_path := build_path || '"';
                WHILE (regexp_like(buf, '^[[:alnum:]\_ ]+', 'c')) LOOP
                    build_path := build_path || buf;
                    next_char();
                END LOOP;
                build_path := build_path || '"';
            ELSE
                raise_application_error(-20110,
                                        'JSON Path parse error: expected . or [ found ' || buf ||
                                        ' at position ' || indx);
            END IF;
        
        END LOOP;
    
        build_path := build_path || ']';
        build_path := REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(build_path,
                                                              chr(9),
                                                              '\t'),
                                                      chr(10),
                                                      '\n'),
                                              chr(13),
                                              '\f'),
                                      chr(8),
                                      '\b'),
                              chr(14),
                              '\r');
    
        ret := pljson_list(build_path);
        IF (base != 1) THEN
            --fix base 0 to base 1
            DECLARE
                elem pljson_value;
            BEGIN
                FOR i IN 1 .. ret.count LOOP
                    elem := ret.get(i);
                    IF (elem.is_number) THEN
                        ret.replace(i, elem.get_number() + 1);
                    END IF;
                END LOOP;
            END;
        END IF;
    
        RETURN ret;
    END parsepath;

    --JSON Path getters
    FUNCTION get_json_value
    (
        obj    pljson,
        v_path VARCHAR2,
        base   NUMBER DEFAULT 1
    ) RETURN pljson_value AS
        path pljson_list;
        ret  pljson_value;
        o    pljson;
        l    pljson_list;
    BEGIN
        path := parsepath(v_path, base);
        ret  := obj.to_json_value;
        IF (path.count = 0) THEN
            RETURN ret;
        END IF;
    
        FOR i IN 1 .. path.count LOOP
            IF (path.get(i).is_string()) THEN
                --string fetch only on json
                o   := pljson(ret);
                ret := o.get(path.get(i).get_string());
            ELSE
                --number fetch on json and json_list
                IF (ret.is_array()) THEN
                    l   := pljson_list(ret);
                    ret := l.get(path.get(i).get_number());
                ELSE
                    o   := pljson(ret);
                    l   := o.get_values();
                    ret := l.get(path.get(i).get_number());
                END IF;
            END IF;
        END LOOP;
    
        RETURN ret;
    EXCEPTION
        WHEN scanner_exception THEN
            RAISE;
        WHEN parser_exception THEN
            RAISE;
        WHEN jext_exception THEN
            RAISE;
        WHEN OTHERS THEN
            RETURN NULL;
    END get_json_value;

    --JSON Path getters
    FUNCTION get_string
    (
        obj  pljson,
        path VARCHAR2,
        base NUMBER DEFAULT 1
    ) RETURN VARCHAR2 AS
        temp pljson_value;
    BEGIN
        temp := get_json_value(obj, path, base);
        IF (temp IS NULL OR NOT temp.is_string) THEN
            RETURN NULL;
        ELSE
            RETURN temp.get_string;
        END IF;
    END;

    FUNCTION get_number
    (
        obj  pljson,
        path VARCHAR2,
        base NUMBER DEFAULT 1
    ) RETURN NUMBER AS
        temp pljson_value;
    BEGIN
        temp := get_json_value(obj, path, base);
        IF (temp IS NULL OR NOT temp.is_number) THEN
            RETURN NULL;
        ELSE
            RETURN temp.get_number;
        END IF;
    END;

    FUNCTION get_double
    (
        obj  pljson,
        path VARCHAR2,
        base NUMBER DEFAULT 1
    ) RETURN binary_double AS
        temp pljson_value;
    BEGIN
        temp := get_json_value(obj, path, base);
        IF (temp IS NULL OR NOT temp.is_number) THEN
            RETURN NULL;
        ELSE
            RETURN temp.get_double;
        END IF;
    END;

    FUNCTION get_json
    (
        obj  pljson,
        path VARCHAR2,
        base NUMBER DEFAULT 1
    ) RETURN pljson AS
        temp pljson_value;
    BEGIN
        temp := get_json_value(obj, path, base);
        IF (temp IS NULL OR NOT temp.is_object) THEN
            RETURN NULL;
        ELSE
            RETURN pljson(temp);
        END IF;
    END;

    FUNCTION get_json_list
    (
        obj  pljson,
        path VARCHAR2,
        base NUMBER DEFAULT 1
    ) RETURN pljson_list AS
        temp pljson_value;
    BEGIN
        temp := get_json_value(obj, path, base);
        IF (temp IS NULL OR NOT temp.is_array) THEN
            RETURN NULL;
        ELSE
            RETURN pljson_list(temp);
        END IF;
    END;

    FUNCTION get_bool
    (
        obj  pljson,
        path VARCHAR2,
        base NUMBER DEFAULT 1
    ) RETURN BOOLEAN AS
        temp pljson_value;
    BEGIN
        temp := get_json_value(obj, path, base);
        IF (temp IS NULL OR NOT temp.is_bool) THEN
            RETURN NULL;
        ELSE
            RETURN temp.get_bool;
        END IF;
    END;

    FUNCTION get_date
    (
        obj  pljson,
        path VARCHAR2,
        base NUMBER DEFAULT 1
    ) RETURN DATE AS
        temp pljson_value;
    BEGIN
        temp := get_json_value(obj, path, base);
        IF (temp IS NULL OR NOT is_date(temp)) THEN
            RETURN NULL;
        ELSE
            RETURN pljson_ext.to_date(temp);
        END IF;
    END;

    /* JSON Path putter internal function */
    PROCEDURE put_internal
    (
        obj    IN OUT NOCOPY pljson,
        v_path VARCHAR2,
        elem   pljson_value,
        base   NUMBER
    ) AS
        val           pljson_value := elem;
        path          pljson_list;
        backreference pljson_list := pljson_list();
    
        keyval    pljson_value;
        keynum    NUMBER;
        keystring VARCHAR2(4000);
        temp      pljson_value := obj.to_json_value;
        obj_temp  pljson;
        list_temp pljson_list;
        inserter  pljson_value;
    BEGIN
        path := pljson_ext.parsepath(v_path, base);
        IF (path.count = 0) THEN
            raise_application_error(-20110,
                                    'PLJSON_EXT put error: cannot put with empty string.');
        END IF;
    
        --build backreference
        FOR i IN 1 .. path.count LOOP
            --backreference.print(false);
            keyval := path.get(i);
            IF (keyval.is_number()) THEN
                --number index
                keynum := keyval.get_number();
                IF ((NOT temp.is_object()) AND (NOT temp.is_array())) THEN
                    IF (val IS NULL) THEN
                        RETURN;
                    END IF;
                    backreference.remove_last;
                    temp := pljson_list().to_json_value();
                    backreference.append(temp);
                END IF;
            
                IF (temp.is_object()) THEN
                    obj_temp := pljson(temp);
                    IF (obj_temp.count < keynum) THEN
                        IF (val IS NULL) THEN
                            RETURN;
                        END IF;
                        raise_application_error(-20110,
                                                'PLJSON_EXT put error: access object with too few members.');
                    END IF;
                    temp := obj_temp.get(keynum);
                ELSE
                    list_temp := pljson_list(temp);
                    IF (list_temp.count < keynum) THEN
                        IF (val IS NULL) THEN
                            RETURN;
                        END IF;
                        --raise error or quit if val is null
                        FOR i IN list_temp.count + 1 .. keynum LOOP
                            list_temp.append(pljson_value.makenull);
                        END LOOP;
                        backreference.remove_last;
                        backreference.append(list_temp);
                    END IF;
                
                    temp := list_temp.get(keynum);
                END IF;
            ELSE
                --string index
                keystring := keyval.get_string();
                IF (NOT temp.is_object()) THEN
                    --backreference.print;
                    IF (val IS NULL) THEN
                        RETURN;
                    END IF;
                    backreference.remove_last;
                    temp := pljson().to_json_value();
                    backreference.append(temp);
                    --raise_application_error(-20110, 'PLJSON_EXT put error: trying to access a non object with a string.');
                END IF;
                obj_temp := pljson(temp);
                temp     := obj_temp.get(keystring);
            END IF;
        
            IF (temp IS NULL) THEN
                IF (val IS NULL) THEN
                    RETURN;
                END IF;
                --what to expect?
                keyval := path.get(i + 1);
                IF (keyval IS NOT NULL AND keyval.is_number()) THEN
                    temp := pljson_list().to_json_value;
                ELSE
                    temp := pljson().to_json_value;
                END IF;
            END IF;
            backreference.append(temp);
        END LOOP;
    
        --  backreference.print(false);
        --  path.print(false);
    
        --use backreference and path together
        inserter := val;
        FOR i IN REVERSE 1 .. backreference.count LOOP
            -- inserter.print(false);
            IF (i = 1) THEN
                keyval := path.get(1);
                IF (keyval.is_string()) THEN
                    keystring := keyval.get_string();
                ELSE
                    keynum := keyval.get_number();
                    DECLARE
                        t1 pljson_value := obj.get(keynum);
                    BEGIN
                        keystring := t1.mapname;
                    END;
                END IF;
                IF (inserter IS NULL) THEN
                    obj.remove(keystring);
                ELSE
                    obj.put(keystring, inserter);
                END IF;
            ELSE
                temp := backreference.get(i - 1);
                IF (temp.is_object()) THEN
                    keyval   := path.get(i);
                    obj_temp := pljson(temp);
                    IF (keyval.is_string()) THEN
                        keystring := keyval.get_string();
                    ELSE
                        keynum := keyval.get_number();
                        DECLARE
                            t1 pljson_value := obj_temp.get(keynum);
                        BEGIN
                            keystring := t1.mapname;
                        END;
                    END IF;
                    IF (inserter IS NULL) THEN
                        obj_temp.remove(keystring);
                        IF (obj_temp.count > 0) THEN
                            inserter := obj_temp.to_json_value;
                        END IF;
                    ELSE
                        obj_temp.put(keystring, inserter);
                        inserter := obj_temp.to_json_value;
                    END IF;
                ELSE
                    --array only number
                    keynum    := path.get(i).get_number();
                    list_temp := pljson_list(temp);
                    list_temp.remove(keynum);
                    IF (NOT inserter IS NULL) THEN
                        list_temp.append(inserter, keynum);
                        inserter := list_temp.to_json_value;
                    ELSE
                        IF (list_temp.count > 0) THEN
                            inserter := list_temp.to_json_value;
                        END IF;
                    END IF;
                END IF;
            END IF;
        
        END LOOP;
    
    END put_internal;

    /* JSON Path putters */
    PROCEDURE put
    (
        obj  IN OUT NOCOPY pljson,
        path VARCHAR2,
        elem VARCHAR2,
        base NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF elem IS NULL THEN
            put_internal(obj, path, pljson_value(), base);
        ELSE
            put_internal(obj, path, pljson_value(elem), base);
        END IF;
    END;

    PROCEDURE put
    (
        obj  IN OUT NOCOPY pljson,
        path VARCHAR2,
        elem NUMBER,
        base NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF elem IS NULL THEN
            put_internal(obj, path, pljson_value(), base);
        ELSE
            put_internal(obj, path, pljson_value(elem), base);
        END IF;
    END;

    PROCEDURE put
    (
        obj  IN OUT NOCOPY pljson,
        path VARCHAR2,
        elem binary_double,
        base NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF elem IS NULL THEN
            put_internal(obj, path, pljson_value(), base);
        ELSE
            put_internal(obj, path, pljson_value(elem), base);
        END IF;
    END;

    PROCEDURE put
    (
        obj  IN OUT NOCOPY pljson,
        path VARCHAR2,
        elem pljson,
        base NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF elem IS NULL THEN
            put_internal(obj, path, pljson_value(), base);
        ELSE
            put_internal(obj, path, elem.to_json_value, base);
        END IF;
    END;

    PROCEDURE put
    (
        obj  IN OUT NOCOPY pljson,
        path VARCHAR2,
        elem pljson_list,
        base NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF elem IS NULL THEN
            put_internal(obj, path, pljson_value(), base);
        ELSE
            put_internal(obj, path, elem.to_json_value, base);
        END IF;
    END;

    PROCEDURE put
    (
        obj  IN OUT NOCOPY pljson,
        path VARCHAR2,
        elem BOOLEAN,
        base NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF elem IS NULL THEN
            put_internal(obj, path, pljson_value(), base);
        ELSE
            put_internal(obj, path, pljson_value(elem), base);
        END IF;
    END;

    PROCEDURE put
    (
        obj  IN OUT NOCOPY pljson,
        path VARCHAR2,
        elem pljson_value,
        base NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF elem IS NULL THEN
            put_internal(obj, path, pljson_value(), base);
        ELSE
            put_internal(obj, path, elem, base);
        END IF;
    END;

    PROCEDURE put
    (
        obj  IN OUT NOCOPY pljson,
        path VARCHAR2,
        elem DATE,
        base NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF elem IS NULL THEN
            put_internal(obj, path, pljson_value(), base);
        ELSE
            put_internal(obj, path, pljson_ext.to_json_value(elem), base);
        END IF;
    END;

    PROCEDURE remove
    (
        obj  IN OUT NOCOPY pljson,
        path VARCHAR2,
        base NUMBER DEFAULT 1
    ) AS
    BEGIN
        pljson_ext.put_internal(obj, path, NULL, base);
        --    if(json_ext.get_json_value(obj,path) is not null) then
        --    end if;
    END remove;

    --Pretty print with JSON Path
    FUNCTION pp
    (
        obj    pljson,
        v_path VARCHAR2
    ) RETURN VARCHAR2 AS
        json_part pljson_value;
    BEGIN
        json_part := pljson_ext.get_json_value(obj, v_path);
        IF (json_part IS NULL) THEN
            RETURN '';
        ELSE
            RETURN pljson_printer.pretty_print_any(json_part); --escapes a possible internal string
        END IF;
    END pp;

    PROCEDURE pp
    (
        obj    pljson,
        v_path VARCHAR2
    ) AS --using dbms_output.put_line
    BEGIN
        dbms_output.put_line(pp(obj, v_path));
    END pp;

    -- spaces = false!
    PROCEDURE pp_htp
    (
        obj    pljson,
        v_path VARCHAR2
    ) AS
        --using htp.print
        json_part pljson_value;
    BEGIN
        json_part := pljson_ext.get_json_value(obj, v_path);
        IF (json_part IS NULL) THEN
            htp.print;
        ELSE
            htp.print(pljson_printer.pretty_print_any(json_part, FALSE));
        END IF;
    END pp_htp;

    FUNCTION base64(binarydata BLOB) RETURN pljson_list AS
        obj pljson_list := pljson_list();
        c   CLOB := empty_clob();
    
        v_clob_offset  NUMBER := 1;
        v_lang_context NUMBER := dbms_lob.default_lang_ctx;
        v_amount       PLS_INTEGER;
    BEGIN
        dbms_lob.createtemporary(c, TRUE);
        c             := encodebase64blob2clob(binarydata);
        v_amount      := dbms_lob.getlength(c);
        v_clob_offset := 1;
        WHILE (v_clob_offset < v_amount) LOOP
            obj.append(dbms_lob.substr(c, 4000, v_clob_offset));
            v_clob_offset := v_clob_offset + 4000;
        END LOOP;
        dbms_lob.freetemporary(c);
        RETURN obj;
    
    END base64;

    FUNCTION base64(l pljson_list) RETURN BLOB AS
        c    CLOB := empty_clob();
        bret BLOB;
    
        v_lang_context NUMBER := dbms_lob.default_lang_ctx;
    BEGIN
        dbms_lob.createtemporary(c, TRUE);
        FOR i IN 1 .. l.count LOOP
            dbms_lob.append(c, l.get(i).get_string());
        END LOOP;
        bret := decodebase64clob2blob(c);
        dbms_lob.freetemporary(c);
        RETURN bret;
    END base64;

    FUNCTION encode(binarydata BLOB) RETURN pljson_value AS
        obj            pljson_value;
        c              CLOB;
        v_lang_context NUMBER := dbms_lob.default_lang_ctx;
    BEGIN
        dbms_lob.createtemporary(c, TRUE);
        c   := encodebase64blob2clob(binarydata);
        obj := pljson_value(c);
    
        dbms_lob.freetemporary(c);
        RETURN obj;
    END encode;

    FUNCTION decode(v pljson_value) RETURN BLOB AS
        c    CLOB := empty_clob();
        bret BLOB;
    
        v_lang_context NUMBER := dbms_lob.default_lang_ctx;
    BEGIN
        dbms_lob.createtemporary(c, TRUE);
        v.get_string(c);
        bret := decodebase64clob2blob(c);
        dbms_lob.freetemporary(c);
        RETURN bret;
    
    END decode;

    FUNCTION clob2blob(p_clob IN CLOB) RETURN BLOB AS
        l_blob        BLOB;
        l_dest_offset INTEGER := 1;
        l_src_offset  INTEGER := 1;
        l_lang_ctx    INTEGER := dbms_lob.default_lang_ctx;
        l_warning     INTEGER;
    BEGIN
        IF p_clob IS NULL THEN
            RETURN NULL;
        END IF;
    
        dbms_lob.createtemporary(lob_loc => l_blob, cache => FALSE);
    
        dbms_lob.converttoblob(dest_lob     => l_blob,
                               src_clob     => p_clob,
                               amount       => dbms_lob.lobmaxsize,
                               dest_offset  => l_dest_offset,
                               src_offset   => l_src_offset,
                               blob_csid    => dbms_lob.default_csid,
                               lang_context => l_lang_ctx,
                               warning      => l_warning);
    
        assert(l_warning = dbms_lob.no_warning,
               'failed to convert clob to blob: ' || l_warning);
    
        RETURN l_blob;
    END clob2blob;

    FUNCTION blob2clob
    (
        p_blob      IN BLOB,
        p_blob_csid IN INTEGER DEFAULT dbms_lob.default_csid
    ) RETURN CLOB AS
        l_clob         CLOB;
        l_dest_offset  INTEGER := 1;
        l_src_offset   INTEGER := 1;
        l_lang_context INTEGER := dbms_lob.default_lang_ctx;
        l_warning      INTEGER;
    BEGIN
        assert(p_blob_csid IS NOT NULL,
               'p_blob_csid is required: ' || p_blob_csid);
        IF p_blob IS NULL THEN
            RETURN NULL;
        END IF;
    
        dbms_lob.createtemporary(lob_loc => l_clob, cache => FALSE);
    
        dbms_lob.converttoclob(dest_lob     => l_clob,
                               src_blob     => p_blob,
                               amount       => dbms_lob.lobmaxsize,
                               dest_offset  => l_dest_offset,
                               src_offset   => l_src_offset,
                               blob_csid    => p_blob_csid,
                               lang_context => l_lang_context,
                               warning      => l_warning);
    
        assert(l_warning = dbms_lob.no_warning,
               'failed to convert blob to clob: ' || l_warning);
    
        RETURN l_clob;
    END blob2clob;
END pljson_ext;
/
