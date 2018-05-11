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
