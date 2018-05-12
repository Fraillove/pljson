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

CREATE OR REPLACE TYPE BODY pljson AS

    /* Constructors */
    CONSTRUCTOR FUNCTION pljson RETURN SELF AS RESULT AS
    BEGIN
        self.json_data           := pljson_value_array();
        self.check_for_duplicate := 1;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson(str VARCHAR2) RETURN SELF AS RESULT AS
    BEGIN
        SELF                     := pljson_parser.parser(str);
        self.check_for_duplicate := 1;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson(str IN CLOB) RETURN SELF AS RESULT AS
    BEGIN
        SELF                     := pljson_parser.parser(str);
        self.check_for_duplicate := 1;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson
    (
        str     IN BLOB,
        charset VARCHAR2 DEFAULT 'UTF8'
    ) RETURN SELF AS RESULT AS
        c_str CLOB;
    BEGIN
        c_str                    := pljson_ext.blob2clob(str, charset);
        SELF                     := pljson_parser.parser(c_str);
        self.check_for_duplicate := 1;
        dbms_lob.freetemporary(c_str);
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson(str_array pljson_varray) RETURN SELF AS RESULT AS
        new_pair   BOOLEAN := TRUE;
        pair_name  VARCHAR2(32767);
        pair_value VARCHAR2(32767);
    BEGIN
        self.json_data           := pljson_value_array();
        self.check_for_duplicate := 1;
        FOR i IN str_array.first .. str_array.last LOOP
            IF new_pair THEN
                pair_name := str_array(i);
                new_pair  := FALSE;
            ELSE
                pair_value := str_array(i);
                put(pair_name, pair_value);
                new_pair := TRUE;
            END IF;
        END LOOP;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson(elem pljson_value) RETURN SELF AS RESULT AS
    BEGIN
        SELF                     := treat(elem.object_or_array AS pljson);
        self.check_for_duplicate := 1;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson(l IN OUT NOCOPY pljson_list)
        RETURN SELF AS RESULT AS
    BEGIN
        FOR i IN 1 .. l.list_data.count LOOP
            IF (l.list_data(i)
               .mapname IS NULL OR l.list_data(i).mapname LIKE 'row%') THEN
                l.list_data(i).mapname := 'row' || i;
            END IF;
            l.list_data(i).mapindx := i;
        END LOOP;
    
        self.json_data           := l.list_data;
        self.check_for_duplicate := 1;
        RETURN;
    END;

    /* Member setter methods */
    MEMBER PROCEDURE remove
    (
        SELF      IN OUT NOCOPY pljson,
        pair_name VARCHAR2
    ) AS
        temp pljson_value;
        indx PLS_INTEGER;
    
        FUNCTION get_member(pair_name VARCHAR2) RETURN pljson_value AS
            indx PLS_INTEGER;
        BEGIN
            indx := json_data.first;
            LOOP
                EXIT WHEN indx IS NULL;
                IF (pair_name IS NULL AND json_data(indx).mapname IS NULL) THEN
                    RETURN json_data(indx);
                END IF;
                IF (json_data(indx).mapname = pair_name) THEN
                    RETURN json_data(indx);
                END IF;
                indx := json_data.next(indx);
            END LOOP;
            RETURN NULL;
        END;
    BEGIN
        temp := get_member(pair_name);
        IF (temp IS NULL) THEN
            RETURN;
        END IF;
    
        indx := json_data.next(temp.mapindx);
        LOOP
            EXIT WHEN indx IS NULL;
            json_data(indx).mapindx := indx - 1;
            json_data(indx - 1) := json_data(indx);
            indx := json_data.next(indx);
        END LOOP;
        json_data.trim(1);
        --num_elements := num_elements - 1;
    END;

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson_value,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
        insert_value pljson_value := nvl(pair_value, pljson_value.makenull);
        indx         PLS_INTEGER;
        x            NUMBER;
        temp         pljson_value;
        FUNCTION get_member(pair_name VARCHAR2) RETURN pljson_value AS
            indx PLS_INTEGER;
        BEGIN
            indx := json_data.first;
            LOOP
                EXIT WHEN indx IS NULL;
                IF (pair_name IS NULL AND json_data(indx).mapname IS NULL) THEN
                    RETURN json_data(indx);
                END IF;
                IF (json_data(indx).mapname = pair_name) THEN
                    RETURN json_data(indx);
                END IF;
                indx := json_data.next(indx);
            END LOOP;
            RETURN NULL;
        END;
    BEGIN
    
        /*    if(pair_name is null) then
          raise_application_error(-20102, 'JSON put-method type error: name cannot be null');
        end if;*/
        insert_value.mapname := pair_name;
        IF (self.check_for_duplicate = 1) THEN
            temp := get_member(pair_name);
        ELSE
            temp := NULL;
        END IF;
        IF (temp IS NOT NULL) THEN
            insert_value.mapindx := temp.mapindx;
            json_data(temp.mapindx) := insert_value;
            RETURN;
        ELSIF (position IS NULL OR position > self.count) THEN
            json_data.extend(1);
            insert_value.mapindx := json_data.count;
            json_data(json_data.count) := insert_value;
            --self.print;
        ELSIF (position < 2) THEN
            indx := json_data.last;
            json_data.extend;
            LOOP
                EXIT WHEN indx IS NULL;
                temp := json_data(indx);
                temp.mapindx := indx + 1;
                json_data(temp.mapindx) := temp;
                indx := json_data.prior(indx);
            END LOOP;
            insert_value.mapindx := 1;
            json_data(1) := insert_value;
        ELSE
            indx := json_data.last;
            json_data.extend;
            LOOP
                temp := json_data(indx);
                temp.mapindx := indx + 1;
                json_data(temp.mapindx) := temp;
                EXIT WHEN indx = position;
                indx := json_data.prior(indx);
            END LOOP;
            insert_value.mapindx := position;
            json_data(position) := insert_value;
        END IF;
    END;

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value VARCHAR2,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        put(pair_name, pljson_value(pair_value), position);
    END;

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value NUMBER,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        IF (pair_value IS NULL) THEN
            put(pair_name, pljson_value(), position);
        ELSE
            put(pair_name, pljson_value(pair_value), position);
        END IF;
    END;

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value binary_double,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        IF (pair_value IS NULL) THEN
            put(pair_name, pljson_value(), position);
        ELSE
            put(pair_name, pljson_value(pair_value), position);
        END IF;
    END;

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value BOOLEAN,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        IF (pair_value IS NULL) THEN
            put(pair_name, pljson_value(), position);
        ELSE
            put(pair_name, pljson_value(pair_value), position);
        END IF;
    END;

    MEMBER PROCEDURE check_duplicate
    (
        SELF  IN OUT NOCOPY pljson,
        v_set BOOLEAN
    ) AS
    BEGIN
        IF (v_set) THEN
            check_for_duplicate := 1;
        ELSE
            check_for_duplicate := 0;
        END IF;
    END;

    /* deprecated putters */
    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        IF (pair_value IS NULL) THEN
            put(pair_name, pljson_value(), position);
        ELSE
            put(pair_name, pair_value.to_json_value, position);
        END IF;
    END;

    MEMBER PROCEDURE put
    (
        SELF       IN OUT NOCOPY pljson,
        pair_name  VARCHAR2,
        pair_value pljson_list,
        position   PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        IF (pair_value IS NULL) THEN
            put(pair_name, pljson_value(), position);
        ELSE
            put(pair_name, pair_value.to_json_value, position);
        END IF;
    END;

    /* Member getter methods */
    MEMBER FUNCTION COUNT RETURN NUMBER AS
    BEGIN
        RETURN self.json_data.count;
    END;

    MEMBER FUNCTION get(pair_name VARCHAR2) RETURN pljson_value AS
        indx PLS_INTEGER;
    BEGIN
        indx := json_data.first;
        LOOP
            EXIT WHEN indx IS NULL;
            IF (pair_name IS NULL AND json_data(indx).mapname IS NULL) THEN
                RETURN json_data(indx);
            END IF;
            IF (json_data(indx).mapname = pair_name) THEN
                RETURN json_data(indx);
            END IF;
            indx := json_data.next(indx);
        END LOOP;
        RETURN NULL;
    END;

    MEMBER FUNCTION get(position PLS_INTEGER) RETURN pljson_value AS
    BEGIN
        IF (self.count >= position AND position > 0) THEN
            RETURN self.json_data(position);
        END IF;
        RETURN NULL; -- do not throw error, just return null
    END;

    MEMBER FUNCTION index_of(pair_name VARCHAR2) RETURN NUMBER AS
        indx PLS_INTEGER;
    BEGIN
        indx := json_data.first;
        LOOP
            EXIT WHEN indx IS NULL;
            IF (pair_name IS NULL AND json_data(indx).mapname IS NULL) THEN
                RETURN indx;
            END IF;
            IF (json_data(indx).mapname = pair_name) THEN
                RETURN indx;
            END IF;
            indx := json_data.next(indx);
        END LOOP;
        RETURN - 1;
    END;

    MEMBER FUNCTION exist(pair_name VARCHAR2) RETURN BOOLEAN AS
    BEGIN
        RETURN(self.get(pair_name) IS NOT NULL);
    END;

    /* Output methods */
    MEMBER FUNCTION to_char
    (
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2 AS
    BEGIN
        IF (spaces IS NULL) THEN
            RETURN pljson_printer.pretty_print(SELF,
                                               line_length => chars_per_line);
        ELSE
            RETURN pljson_printer.pretty_print(SELF,
                                               spaces,
                                               line_length => chars_per_line);
        END IF;
    END;

    MEMBER PROCEDURE to_clob
    (
        SELF           IN pljson,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    ) AS
    BEGIN
        IF (spaces IS NULL) THEN
            pljson_printer.pretty_print(SELF,
                                        FALSE,
                                        buf,
                                        line_length => chars_per_line,
                                        erase_clob  => erase_clob);
        ELSE
            pljson_printer.pretty_print(SELF,
                                        spaces,
                                        buf,
                                        line_length => chars_per_line,
                                        erase_clob  => erase_clob);
        END IF;
    END;

    MEMBER PROCEDURE print
    (
        SELF           IN pljson,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
        --32512 is the real maximum in sqldeveloper
        my_clob CLOB;
    BEGIN
        my_clob := empty_clob();
        dbms_lob.createtemporary(my_clob, TRUE);
        pljson_printer.pretty_print(SELF,
                                    spaces,
                                    my_clob,
                                    CASE WHEN(chars_per_line > 32512) THEN
                                    32512 ELSE chars_per_line END);
        pljson_printer.dbms_output_clob(my_clob,
                                        pljson_printer.newline_char,
                                        jsonp);
        dbms_lob.freetemporary(my_clob);
    END;

    MEMBER PROCEDURE htp
    (
        SELF           IN pljson,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
        my_clob CLOB;
    BEGIN
        my_clob := empty_clob();
        dbms_lob.createtemporary(my_clob, TRUE);
        pljson_printer.pretty_print(SELF, spaces, my_clob, chars_per_line);
        pljson_printer.htp_output_clob(my_clob, jsonp);
        dbms_lob.freetemporary(my_clob);
    END;

    MEMBER FUNCTION to_json_value RETURN pljson_value AS
    BEGIN
        RETURN pljson_value(SELF);
    END;

    /* json path */
    MEMBER FUNCTION path
    (
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) RETURN pljson_value AS
    BEGIN
        RETURN pljson_ext.get_json_value(SELF, json_path, base);
    END path;

    /* json path_put */
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson_value,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        pljson_ext.put(SELF, json_path, elem, base);
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      VARCHAR2,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        pljson_ext.put(SELF, json_path, elem, base);
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      NUMBER,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            pljson_ext.put(SELF, json_path, pljson_value(), base);
        ELSE
            pljson_ext.put(SELF, json_path, elem, base);
        END IF;
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      binary_double,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            pljson_ext.put(SELF, json_path, pljson_value(), base);
        ELSE
            pljson_ext.put(SELF, json_path, elem, base);
        END IF;
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      BOOLEAN,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            pljson_ext.put(SELF, json_path, pljson_value(), base);
        ELSE
            pljson_ext.put(SELF, json_path, elem, base);
        END IF;
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson_list,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            pljson_ext.put(SELF, json_path, pljson_value(), base);
        ELSE
            pljson_ext.put(SELF, json_path, elem, base);
        END IF;
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        elem      pljson,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            pljson_ext.put(SELF, json_path, pljson_value(), base);
        ELSE
            pljson_ext.put(SELF, json_path, elem, base);
        END IF;
    END path_put;

    MEMBER PROCEDURE path_remove
    (
        SELF      IN OUT NOCOPY pljson,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) AS
    BEGIN
        pljson_ext.remove(SELF, json_path, base);
    END path_remove;

    MEMBER FUNCTION get_keys RETURN pljson_list AS
        keys pljson_list;
        indx PLS_INTEGER;
    BEGIN
        keys := pljson_list();
        indx := json_data.first;
        LOOP
            EXIT WHEN indx IS NULL;
            keys.append(json_data(indx).mapname);
            indx := json_data.next(indx);
        END LOOP;
        RETURN keys;
    END;

    MEMBER FUNCTION get_values RETURN pljson_list AS
        vals pljson_list := pljson_list();
    BEGIN
        vals.list_data := self.json_data;
        RETURN vals;
    END;

    MEMBER PROCEDURE remove_duplicates(SELF IN OUT NOCOPY pljson) AS
    BEGIN
        pljson_parser.remove_duplicates(SELF);
    END remove_duplicates;

END;
/

/*
DECLARE
    myjson  pljson := pljson();
    myjson1 pljson := pljson('{"foo": "bar", "bar": "foo"}');

BEGIN
    myjson.put('foo', 'bar');
    do.pl(myjson.get('foo').to_char());
    do.pl(pljson('{"foo": "bar"}').get('foo').to_char());
    pljson(pljson('{"foo": {"bar": "baz"}}').get('foo')).print();
    myjson1.get_keys().print();
    myjson1.get_values().print();
    do.pl(myjson1.count());
    myjson1.remove('foo');
    myjson1.print();
    do.pl(myjson1.count());
END;

*/
