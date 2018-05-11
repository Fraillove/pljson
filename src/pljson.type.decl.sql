set termout off
create or replace type pljson_varray as table of varchar2(32767);
/

set termout on
CREATE OR REPLACE TYPE pljson force UNDER pljson_element
(

    json_data           pljson_value_array,
    check_for_duplicate NUMBER,

    CONSTRUCTOR FUNCTION pljson RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson(str VARCHAR2) RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson(str IN CLOB) RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson
    (
        str     IN BLOB,
        charset VARCHAR2 DEFAULT 'UTF8'
    ) RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson(str_array pljson_varray)
        RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson(elem pljson_value) RETURN SELF AS RESULT,

    CONSTRUCTOR FUNCTION pljson(l IN OUT NOCOPY pljson_list)
        RETURN SELF AS RESULT,

    MEMBER PROCEDURE remove(pair_name VARCHAR2),

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson_value,
        position   PLS_INTEGER DEFAULT NULL
    ),

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value VARCHAR2,
        position   PLS_INTEGER DEFAULT NULL
    ),

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value NUMBER,
        position   PLS_INTEGER DEFAULT NULL
    ),

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value binary_double,
        position   PLS_INTEGER DEFAULT NULL
    ),

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value BOOLEAN,
        position   PLS_INTEGER DEFAULT NULL
    ),

    MEMBER PROCEDURE check_duplicate
    (
        SELF  IN OUT NOCOPY pljson,
        v_set BOOLEAN
    ),
    MEMBER PROCEDURE remove_duplicates(SELF IN OUT NOCOPY pljson),

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson,
        position   PLS_INTEGER DEFAULT NULL
    ),

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson_list,
        position   PLS_INTEGER DEFAULT NULL
    ),

    MEMBER FUNCTION COUNT RETURN NUMBER,

    MEMBER FUNCTION get(pair_name VARCHAR2) RETURN pljson_value,

    MEMBER FUNCTION get(position PLS_INTEGER) RETURN pljson_value,

    MEMBER FUNCTION index_of(pair_name VARCHAR2) RETURN NUMBER,

    MEMBER FUNCTION exist(pair_name VARCHAR2) RETURN BOOLEAN,

    MEMBER FUNCTION to_char
    (
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2,

    MEMBER PROCEDURE to_clob
    (
        SELF           IN pljson,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    ),

    MEMBER PROCEDURE print
    (
        SELF           IN pljson,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    ), --32512 is maximum

    MEMBER PROCEDURE htp
    (
        SELF           IN pljson,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    ),

    MEMBER FUNCTION to_json_value RETURN pljson_value,

    MEMBER FUNCTION path
    (
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) RETURN pljson_value,

/* json path_put */
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson_value,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      VARCHAR2,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      NUMBER,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      binary_double,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      BOOLEAN,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson_list,
        base      NUMBER DEFAULT 1
    ),
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson,
        base      NUMBER DEFAULT 1
    ),

/* json path_remove */
    MEMBER PROCEDURE path_remove
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ),

/* map functions */

    MEMBER FUNCTION get_values RETURN pljson_list,

    MEMBER FUNCTION get_keys RETURN pljson_list

)
NOT FINAL;
/
