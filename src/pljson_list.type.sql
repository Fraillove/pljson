set termout off
create or replace type pljson_varray as table of varchar2(32767);
/
create or replace type pljson_narray as table of number;
/

set termout on
CREATE OR REPLACE TYPE pljson_list force UNDER pljson_element
(

/** Private variable for internal processing. */
    list_data pljson_value_array,

    CONSTRUCTOR FUNCTION pljson_list RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson_list(str VARCHAR2) RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson_list(str CLOB) RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson_list
    (
        str     BLOB,
        charset VARCHAR2 DEFAULT 'UTF8'
    ) RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson_list(str_array pljson_varray)
        RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson_list(num_array pljson_narray)
        RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson_list(elem pljson_value)
        RETURN SELF AS RESULT,

    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     pljson_value,
        position PLS_INTEGER DEFAULT NULL
    ),
    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     VARCHAR2,
        position PLS_INTEGER DEFAULT NULL
    ),
    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     NUMBER,
        position PLS_INTEGER DEFAULT NULL
    ),
    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     binary_double,
        position PLS_INTEGER DEFAULT NULL
    ),
    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     BOOLEAN,
        position PLS_INTEGER DEFAULT NULL
    ),
    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     pljson_list,
        position PLS_INTEGER DEFAULT NULL
    ),

    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     pljson_value
    ),
    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     VARCHAR2
    ),
    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     NUMBER
    ),
    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     binary_double
    ),
    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     BOOLEAN
    ),
    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     pljson_list
    ),

    MEMBER FUNCTION COUNT RETURN NUMBER,
    MEMBER PROCEDURE remove
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER
    ),
    MEMBER PROCEDURE remove_first(SELF IN OUT NOCOPY pljson_list),
    MEMBER PROCEDURE remove_last(SELF IN OUT NOCOPY pljson_list),
    MEMBER FUNCTION get(position PLS_INTEGER) RETURN pljson_value,
    MEMBER FUNCTION head RETURN pljson_value,
    MEMBER FUNCTION LAST RETURN pljson_value,
    MEMBER FUNCTION tail RETURN pljson_list,

/* Output methods */
    MEMBER FUNCTION to_char
    (
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2,
    MEMBER PROCEDURE to_clob
    (
        SELF           IN pljson_list,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    ),
    MEMBER PROCEDURE print
    (
        SELF           IN pljson_list,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    ), --32512 is maximum
    MEMBER PROCEDURE htp
    (
        SELF           IN pljson_list,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    ),

/* json path */
    MEMBER FUNCTION path
    (
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) RETURN pljson_value,
/* json path_put */
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      pljson_value,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      VARCHAR2,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      NUMBER,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      binary_double,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      BOOLEAN,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      pljson_list,
        base      NUMBER DEFAULT 1
    ),

/* json path_remove */
    MEMBER PROCEDURE path_remove
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ),

    MEMBER FUNCTION to_json_value RETURN pljson_value
)
NOT FINAL;
/
