CREATE OR REPLACE PACKAGE pljson_ac AS
    --json type

    PROCEDURE object_remove
    (
        p_self    IN OUT NOCOPY pljson,
        pair_name VARCHAR2
    );
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson_value,
        position   PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value VARCHAR2,
        position   PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value NUMBER,
        position   PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value binary_double,
        position   PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value BOOLEAN,
        position   PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE object_check_duplicate
    (
        p_self IN OUT NOCOPY pljson,
        v_set  BOOLEAN
    );
    PROCEDURE object_remove_duplicates(p_self IN OUT NOCOPY pljson);

    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson,
        position   PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson_list,
        position   PLS_INTEGER DEFAULT NULL
    );

    FUNCTION object_count(p_self IN pljson) RETURN NUMBER;
    FUNCTION object_get
    (
        p_self    IN pljson,
        pair_name VARCHAR2
    ) RETURN pljson_value;
    FUNCTION object_get
    (
        p_self   IN pljson,
        position PLS_INTEGER
    ) RETURN pljson_value;
    FUNCTION object_index_of
    (
        p_self    IN pljson,
        pair_name VARCHAR2
    ) RETURN NUMBER;
    FUNCTION object_exist
    (
        p_self    IN pljson,
        pair_name VARCHAR2
    ) RETURN BOOLEAN;

    FUNCTION object_to_char
    (
        p_self         IN pljson,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2;
    PROCEDURE object_to_clob
    (
        p_self         IN pljson,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    );
    PROCEDURE object_print
    (
        p_self         IN pljson,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    );
    PROCEDURE object_htp
    (
        p_self         IN pljson,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    );

    FUNCTION object_to_json_value(p_self IN pljson) RETURN pljson_value;
    FUNCTION object_path
    (
        p_self    IN pljson,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) RETURN pljson_value;

    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson_value,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      VARCHAR2,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      NUMBER,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      binary_double,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      BOOLEAN,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson_list,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson,
        base      NUMBER DEFAULT 1
    );

    PROCEDURE object_path_remove
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    );

    FUNCTION object_get_values(p_self IN pljson) RETURN pljson_list;
    FUNCTION object_get_keys(p_self IN pljson) RETURN pljson_list;

    --json_list
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     pljson_value,
        position PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     VARCHAR2,
        position PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     NUMBER,
        position PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     binary_double,
        position PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     BOOLEAN,
        position PLS_INTEGER DEFAULT NULL
    );
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     pljson_list,
        position PLS_INTEGER DEFAULT NULL
    );

    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     pljson_value
    );
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     VARCHAR2
    );
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     NUMBER
    );
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     binary_double
    );
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     BOOLEAN
    );
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     pljson_list
    );

    FUNCTION array_count(p_self IN pljson_list) RETURN NUMBER;
    PROCEDURE array_remove
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER
    );
    PROCEDURE array_remove_first(p_self IN OUT NOCOPY pljson_list);
    PROCEDURE array_remove_last(p_self IN OUT NOCOPY pljson_list);
    FUNCTION array_get
    (
        p_self   IN pljson_list,
        position PLS_INTEGER
    ) RETURN pljson_value;
    FUNCTION array_head(p_self IN pljson_list) RETURN pljson_value;
    FUNCTION array_last(p_self IN pljson_list) RETURN pljson_value;
    FUNCTION array_tail(p_self IN pljson_list) RETURN pljson_list;

    FUNCTION array_to_char
    (
        p_self         IN pljson_list,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2;
    PROCEDURE array_to_clob
    (
        p_self         IN pljson_list,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    );
    PROCEDURE array_print
    (
        p_self         IN pljson_list,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    );
    PROCEDURE array_htp
    (
        p_self         IN pljson_list,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    );

    FUNCTION array_path
    (
        p_self    IN pljson_list,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) RETURN pljson_value;
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      pljson_value,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      VARCHAR2,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      NUMBER,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      binary_double,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      BOOLEAN,
        base      NUMBER DEFAULT 1
    );
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      pljson_list,
        base      NUMBER DEFAULT 1
    );

    PROCEDURE array_path_remove
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    );

    FUNCTION array_to_json_value(p_self IN pljson_list) RETURN pljson_value;

    --json_value

    FUNCTION jv_get_type(p_self IN pljson_value) RETURN VARCHAR2;
    FUNCTION jv_get_string
    (
        p_self        IN pljson_value,
        max_byte_size NUMBER DEFAULT NULL,
        max_char_size NUMBER DEFAULT NULL
    ) RETURN VARCHAR2;
    PROCEDURE jv_get_string
    (
        p_self IN pljson_value,
        buf    IN OUT NOCOPY CLOB
    );
    FUNCTION jv_get_number(p_self IN pljson_value) RETURN NUMBER;
    FUNCTION jv_get_double(p_self IN pljson_value) RETURN binary_double;
    FUNCTION jv_get_bool(p_self IN pljson_value) RETURN BOOLEAN;
    FUNCTION jv_get_null(p_self IN pljson_value) RETURN VARCHAR2;

    FUNCTION jv_is_object(p_self IN pljson_value) RETURN BOOLEAN;
    FUNCTION jv_is_array(p_self IN pljson_value) RETURN BOOLEAN;
    FUNCTION jv_is_string(p_self IN pljson_value) RETURN BOOLEAN;
    FUNCTION jv_is_number(p_self IN pljson_value) RETURN BOOLEAN;
    FUNCTION jv_is_bool(p_self IN pljson_value) RETURN BOOLEAN;
    FUNCTION jv_is_null(p_self IN pljson_value) RETURN BOOLEAN;

    FUNCTION jv_to_char
    (
        p_self         IN pljson_value,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2;
    PROCEDURE jv_to_clob
    (
        p_self         IN pljson_value,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    );
    PROCEDURE jv_print
    (
        p_self         IN pljson_value,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    );
    PROCEDURE jv_htp
    (
        p_self         IN pljson_value,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    );

    FUNCTION jv_value_of
    (
        p_self        IN pljson_value,
        max_byte_size NUMBER DEFAULT NULL,
        max_char_size NUMBER DEFAULT NULL
    ) RETURN VARCHAR2;

END pljson_ac;
/

CREATE OR REPLACE PACKAGE BODY pljson_ac AS
    PROCEDURE object_remove
    (
        p_self    IN OUT NOCOPY pljson,
        pair_name VARCHAR2
    ) AS
    BEGIN
        p_self.remove(pair_name);
    END;
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson_value,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.put(pair_name, pair_value, position);
    END;
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value VARCHAR2,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.put(pair_name, pair_value, position);
    END;
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value NUMBER,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.put(pair_name, pair_value, position);
    END;
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value binary_double,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.put(pair_name, pair_value, position);
    END;
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value BOOLEAN,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.put(pair_name, pair_value, position);
    END;
    PROCEDURE object_check_duplicate
    (
        p_self IN OUT NOCOPY pljson,
        v_set  BOOLEAN
    ) AS
    BEGIN
        p_self.check_duplicate(v_set);
    END;
    PROCEDURE object_remove_duplicates(p_self IN OUT NOCOPY pljson) AS
    BEGIN
        p_self.remove_duplicates;
    END;

    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.put(pair_name, pair_value, position);
    END;
    PROCEDURE object_put
    (
        p_self     IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson_list,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.put(pair_name, pair_value, position);
    END;

    FUNCTION object_count(p_self IN pljson) RETURN NUMBER AS
    BEGIN
        RETURN p_self.count;
    END;
    FUNCTION object_get
    (
        p_self    IN pljson,
        pair_name VARCHAR2
    ) RETURN pljson_value AS
    BEGIN
        RETURN p_self.get(pair_name);
    END;
    FUNCTION object_get
    (
        p_self   IN pljson,
        position PLS_INTEGER
    ) RETURN pljson_value AS
    BEGIN
        RETURN p_self.get(position);
    END;
    FUNCTION object_index_of
    (
        p_self    IN pljson,
        pair_name VARCHAR2
    ) RETURN NUMBER AS
    BEGIN
        RETURN p_self.index_of(pair_name);
    END;
    FUNCTION object_exist
    (
        p_self    IN pljson,
        pair_name VARCHAR2
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN p_self.exist(pair_name);
    END;

    FUNCTION object_to_char
    (
        p_self         IN pljson,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2 AS
    BEGIN
        RETURN p_self.to_char(spaces, chars_per_line);
    END;
    PROCEDURE object_to_clob
    (
        p_self         IN pljson,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    ) AS
    BEGIN
        p_self.to_clob(buf, spaces, chars_per_line, erase_clob);
    END;
    PROCEDURE object_print
    (
        p_self         IN pljson,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
    BEGIN
        p_self.print(spaces, chars_per_line, jsonp);
    END;
    PROCEDURE object_htp
    (
        p_self         IN pljson,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
    BEGIN
        p_self.htp(spaces, chars_per_line, jsonp);
    END;

    FUNCTION object_to_json_value(p_self IN pljson) RETURN pljson_value AS
    BEGIN
        RETURN p_self.to_json_value;
    END;
    FUNCTION object_path
    (
        p_self    IN pljson,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) RETURN pljson_value AS
    BEGIN
        RETURN p_self.path(json_path, base);
    END;

    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson_value,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      VARCHAR2,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      NUMBER,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      binary_double,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      BOOLEAN,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson_list,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE object_path_put
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;

    PROCEDURE object_path_remove
    (
        p_self    IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_remove(json_path, base);
    END;

    FUNCTION object_get_values(p_self IN pljson) RETURN pljson_list AS
    BEGIN
        RETURN p_self.get_values;
    END;
    FUNCTION object_get_keys(p_self IN pljson) RETURN pljson_list AS
    BEGIN
        RETURN p_self.get_keys;
    END;

    --json_list type
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     pljson_value,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.append(elem, position);
    END;
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     VARCHAR2,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.append(elem, position);
    END;
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     NUMBER,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.append(elem, position);
    END;
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     binary_double,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.append(elem, position);
    END;
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     BOOLEAN,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.append(elem, position);
    END;
    PROCEDURE array_append
    (
        p_self   IN OUT NOCOPY pljson_list,
        elem     pljson_list,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        p_self.append(elem, position);
    END;

    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     pljson_value
    ) AS
    BEGIN
        p_self.replace(position, elem);
    END;
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     VARCHAR2
    ) AS
    BEGIN
        p_self.replace(position, elem);
    END;
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     NUMBER
    ) AS
    BEGIN
        p_self.replace(position, elem);
    END;
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     binary_double
    ) AS
    BEGIN
        p_self.replace(position, elem);
    END;
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     BOOLEAN
    ) AS
    BEGIN
        p_self.replace(position, elem);
    END;
    PROCEDURE array_replace
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     pljson_list
    ) AS
    BEGIN
        p_self.replace(position, elem);
    END;

    FUNCTION array_count(p_self IN pljson_list) RETURN NUMBER AS
    BEGIN
        RETURN p_self.count;
    END;
    PROCEDURE array_remove
    (
        p_self   IN OUT NOCOPY pljson_list,
        position PLS_INTEGER
    ) AS
    BEGIN
        p_self.remove(position);
    END;
    PROCEDURE array_remove_first(p_self IN OUT NOCOPY pljson_list) AS
    BEGIN
        p_self.remove_first;
    END;
    PROCEDURE array_remove_last(p_self IN OUT NOCOPY pljson_list) AS
    BEGIN
        p_self.remove_last;
    END;
    FUNCTION array_get
    (
        p_self   IN pljson_list,
        position PLS_INTEGER
    ) RETURN pljson_value AS
    BEGIN
        RETURN p_self.get(position);
    END;
    FUNCTION array_head(p_self IN pljson_list) RETURN pljson_value AS
    BEGIN
        RETURN p_self.head;
    END;
    FUNCTION array_last(p_self IN pljson_list) RETURN pljson_value AS
    BEGIN
        RETURN p_self.last;
    END;
    FUNCTION array_tail(p_self IN pljson_list) RETURN pljson_list AS
    BEGIN
        RETURN p_self.tail;
    END;

    FUNCTION array_to_char
    (
        p_self         IN pljson_list,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2 AS
    BEGIN
        RETURN p_self.to_char(spaces, chars_per_line);
    END;
    PROCEDURE array_to_clob
    (
        p_self         IN pljson_list,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    ) AS
    BEGIN
        p_self.to_clob(buf, spaces, chars_per_line, erase_clob);
    END;
    PROCEDURE array_print
    (
        p_self         IN pljson_list,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
    BEGIN
        p_self.print(spaces, chars_per_line, jsonp);
    END;
    PROCEDURE array_htp
    (
        p_self         IN pljson_list,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
    BEGIN
        p_self.htp(spaces, chars_per_line, jsonp);
    END;

    FUNCTION array_path
    (
        p_self    IN pljson_list,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) RETURN pljson_value AS
    BEGIN
        RETURN p_self.path(json_path, base);
    END;
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      pljson_value,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      VARCHAR2,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      NUMBER,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      binary_double,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      BOOLEAN,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;
    PROCEDURE array_path_put
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      pljson_list,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_put(json_path, elem, base);
    END;

    PROCEDURE array_path_remove
    (
        p_self    IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        p_self.path_remove(json_path, base);
    END;

    FUNCTION array_to_json_value(p_self IN pljson_list) RETURN pljson_value AS
    BEGIN
        RETURN p_self.to_json_value;
    END;

    --json_value

    FUNCTION jv_get_type(p_self IN pljson_value) RETURN VARCHAR2 AS
    BEGIN
        RETURN p_self.get_type;
    END;
    FUNCTION jv_get_string
    (
        p_self        IN pljson_value,
        max_byte_size NUMBER DEFAULT NULL,
        max_char_size NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 AS
    BEGIN
        RETURN p_self.get_string(max_byte_size, max_char_size);
    END;
    PROCEDURE jv_get_string
    (
        p_self IN pljson_value,
        buf    IN OUT NOCOPY CLOB
    ) AS
    BEGIN
        p_self.get_string(buf);
    END;
    FUNCTION jv_get_number(p_self IN pljson_value) RETURN NUMBER AS
    BEGIN
        RETURN p_self.get_number;
    END;
    FUNCTION jv_get_double(p_self IN pljson_value) RETURN binary_double AS
    BEGIN
        RETURN p_self.get_double;
    END;
    FUNCTION jv_get_bool(p_self IN pljson_value) RETURN BOOLEAN AS
    BEGIN
        RETURN p_self.get_bool;
    END;
    FUNCTION jv_get_null(p_self IN pljson_value) RETURN VARCHAR2 AS
    BEGIN
        RETURN p_self.get_null;
    END;

    FUNCTION jv_is_object(p_self IN pljson_value) RETURN BOOLEAN AS
    BEGIN
        RETURN p_self.is_object;
    END;
    FUNCTION jv_is_array(p_self IN pljson_value) RETURN BOOLEAN AS
    BEGIN
        RETURN p_self.is_array;
    END;
    FUNCTION jv_is_string(p_self IN pljson_value) RETURN BOOLEAN AS
    BEGIN
        RETURN p_self.is_string;
    END;
    FUNCTION jv_is_number(p_self IN pljson_value) RETURN BOOLEAN AS
    BEGIN
        RETURN p_self.is_number;
    END;
    FUNCTION jv_is_bool(p_self IN pljson_value) RETURN BOOLEAN AS
    BEGIN
        RETURN p_self.is_bool;
    END;
    FUNCTION jv_is_null(p_self IN pljson_value) RETURN BOOLEAN AS
    BEGIN
        RETURN p_self.is_null;
    END;

    FUNCTION jv_to_char
    (
        p_self         IN pljson_value,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2 AS
    BEGIN
        RETURN p_self.to_char(spaces, chars_per_line);
    END;
    PROCEDURE jv_to_clob
    (
        p_self         IN pljson_value,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    ) AS
    BEGIN
        p_self.to_clob(buf, spaces, chars_per_line, erase_clob);
    END;
    PROCEDURE jv_print
    (
        p_self         IN pljson_value,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
    BEGIN
        p_self.print(spaces, chars_per_line, jsonp);
    END;
    PROCEDURE jv_htp
    (
        p_self         IN pljson_value,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
    BEGIN
        p_self.htp(spaces, chars_per_line, jsonp);
    END;

    FUNCTION jv_value_of
    (
        p_self        IN pljson_value,
        max_byte_size NUMBER DEFAULT NULL,
        max_char_size NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 AS
    BEGIN
        RETURN p_self.value_of(max_byte_size, max_char_size);
    END;

END pljson_ac;
/
