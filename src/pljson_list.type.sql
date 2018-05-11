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

CREATE OR REPLACE TYPE BODY pljson_list AS

    CONSTRUCTOR FUNCTION pljson_list RETURN SELF AS RESULT AS
    BEGIN
        self.list_data := pljson_value_array();
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson_list(str VARCHAR2) RETURN SELF AS RESULT AS
    BEGIN
        SELF := pljson_parser.parse_list(str);
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson_list(str CLOB) RETURN SELF AS RESULT AS
    BEGIN
        SELF := pljson_parser.parse_list(str);
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson_list
    (
        str     BLOB,
        charset VARCHAR2 DEFAULT 'UTF8'
    ) RETURN SELF AS RESULT AS
        c_str CLOB;
    BEGIN
        c_str := pljson_ext.blob2clob(str, charset);
        SELF  := pljson_parser.parse_list(c_str);
        dbms_lob.freetemporary(c_str);
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson_list(str_array pljson_varray)
        RETURN SELF AS RESULT AS
    BEGIN
        self.list_data := pljson_value_array();
        FOR i IN str_array.first .. str_array.last LOOP
            append(str_array(i));
        END LOOP;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson_list(num_array pljson_narray)
        RETURN SELF AS RESULT AS
    BEGIN
        self.list_data := pljson_value_array();
        FOR i IN num_array.first .. num_array.last LOOP
            append(num_array(i));
        END LOOP;
        RETURN;
    END;

    CONSTRUCTOR FUNCTION pljson_list(elem pljson_value) RETURN SELF AS RESULT AS
    BEGIN
        SELF := treat(elem.object_or_array AS pljson_list);
        RETURN;
    END;

    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     pljson_value,
        position PLS_INTEGER DEFAULT NULL
    ) AS
        indx         PLS_INTEGER;
        insert_value pljson_value := nvl(elem, pljson_value);
    BEGIN
        IF (position IS NULL OR position > self.count) THEN
            --end of list
            indx := self.count + 1;
            self.list_data.extend(1);
            self.list_data(indx) := insert_value;
        ELSIF (position < 1) THEN
            --new first
            indx := self.count;
            self.list_data.extend(1);
            FOR x IN REVERSE 1 .. indx LOOP
                self.list_data(x + 1) := self.list_data(x);
            END LOOP;
            self.list_data(1) := insert_value;
        ELSE
            indx := self.count;
            self.list_data.extend(1);
            FOR x IN REVERSE position .. indx LOOP
                self.list_data(x + 1) := self.list_data(x);
            END LOOP;
            self.list_data(position) := insert_value;
        END IF;
    
    END;

    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     VARCHAR2,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        append(pljson_value(elem), position);
    END;

    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     NUMBER,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            append(pljson_value(), position);
        ELSE
            append(pljson_value(elem), position);
        END IF;
    END;

    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     binary_double,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            append(pljson_value(), position);
        ELSE
            append(pljson_value(elem), position);
        END IF;
    END;

    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     BOOLEAN,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            append(pljson_value(), position);
        ELSE
            append(pljson_value(elem), position);
        END IF;
    END;

    MEMBER PROCEDURE append
    (
        SELF     IN OUT NOCOPY pljson_list,
        elem     pljson_list,
        position PLS_INTEGER DEFAULT NULL
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            append(pljson_value(), position);
        ELSE
            append(elem.to_json_value, position);
        END IF;
    END;

    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     pljson_value
    ) AS
        insert_value pljson_value := nvl(elem, pljson_value);
        indx         NUMBER;
    BEGIN
        IF (position > self.count) THEN
            --end of list
            indx := self.count + 1;
            self.list_data.extend(1);
            self.list_data(indx) := insert_value;
        ELSIF (position < 1) THEN
            --maybe an error message here
            NULL;
        ELSE
            self.list_data(position) := insert_value;
        END IF;
    END;

    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     VARCHAR2
    ) AS
    BEGIN
        REPLACE(position, pljson_value(elem));
    END;

    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     NUMBER
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            REPLACE(position, pljson_value());
        ELSE
            REPLACE(position, pljson_value(elem));
        END IF;
    END;

    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     binary_double
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            REPLACE(position, pljson_value());
        ELSE
            REPLACE(position, pljson_value(elem));
        END IF;
    END;

    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     BOOLEAN
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            REPLACE(position, pljson_value());
        ELSE
            REPLACE(position, pljson_value(elem));
        END IF;
    END;

    MEMBER PROCEDURE REPLACE
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER,
        elem     pljson_list
    ) AS
    BEGIN
        IF (elem IS NULL) THEN
            REPLACE(position, pljson_value());
        ELSE
            REPLACE(position, elem.to_json_value);
        END IF;
    END;

    MEMBER FUNCTION COUNT RETURN NUMBER AS
    BEGIN
        RETURN self.list_data.count;
    END;

    MEMBER PROCEDURE remove
    (
        SELF     IN OUT NOCOPY pljson_list,
        position PLS_INTEGER
    ) AS
    BEGIN
        IF (position IS NULL OR position < 1 OR position > self.count) THEN
            RETURN;
        END IF;
        FOR x IN (position + 1) .. self.count LOOP
            self.list_data(x - 1) := self.list_data(x);
        END LOOP;
        self.list_data.trim(1);
    END;

    MEMBER PROCEDURE remove_first(SELF IN OUT NOCOPY pljson_list) AS
    BEGIN
        FOR x IN 2 .. self.count LOOP
            self.list_data(x - 1) := self.list_data(x);
        END LOOP;
        IF (self.count > 0) THEN
            self.list_data.trim(1);
        END IF;
    END;

    MEMBER PROCEDURE remove_last(SELF IN OUT NOCOPY pljson_list) AS
    BEGIN
        IF (self.count > 0) THEN
            self.list_data.trim(1);
        END IF;
    END;

    MEMBER FUNCTION get(position PLS_INTEGER) RETURN pljson_value AS
    BEGIN
        IF (self.count >= position AND position > 0) THEN
            RETURN self.list_data(position);
        END IF;
        RETURN NULL; -- do not throw error, just return null
    END;

    MEMBER FUNCTION head RETURN pljson_value AS
    BEGIN
        IF (self.count > 0) THEN
            RETURN self.list_data(self.list_data.first);
        END IF;
        RETURN NULL; -- do not throw error, just return null
    END;

    MEMBER FUNCTION LAST RETURN pljson_value AS
    BEGIN
        IF (self.count > 0) THEN
            RETURN self.list_data(self.list_data.last);
        END IF;
        RETURN NULL; -- do not throw error, just return null
    END;

    MEMBER FUNCTION tail RETURN pljson_list AS
        t pljson_list;
    BEGIN
        IF (self.count > 0) THEN
            t := pljson_list(self.to_json_value);
            t.remove(1);
            RETURN t;
        ELSE
            RETURN pljson_list();
        END IF;
    END;

    MEMBER FUNCTION to_char
    (
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2 AS
    BEGIN
        IF (spaces IS NULL) THEN
            RETURN pljson_printer.pretty_print_list(SELF,
                                                    line_length => chars_per_line);
        ELSE
            RETURN pljson_printer.pretty_print_list(SELF,
                                                    spaces,
                                                    line_length => chars_per_line);
        END IF;
    END;

    MEMBER PROCEDURE to_clob
    (
        SELF           IN pljson_list,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    ) AS
    BEGIN
        IF (spaces IS NULL) THEN
            pljson_printer.pretty_print_list(SELF,
                                             FALSE,
                                             buf,
                                             line_length => chars_per_line,
                                             erase_clob  => erase_clob);
        ELSE
            pljson_printer.pretty_print_list(SELF,
                                             spaces,
                                             buf,
                                             line_length => chars_per_line,
                                             erase_clob  => erase_clob);
        END IF;
    END;

    MEMBER PROCEDURE print
    (
        SELF           IN pljson_list,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
        --32512 is the real maximum in sqldeveloper
        my_clob CLOB;
    BEGIN
        my_clob := empty_clob();
        dbms_lob.createtemporary(my_clob, TRUE);
        pljson_printer.pretty_print_list(SELF,
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
        SELF           IN pljson_list,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
        my_clob CLOB;
    BEGIN
        my_clob := empty_clob();
        dbms_lob.createtemporary(my_clob, TRUE);
        pljson_printer.pretty_print_list(SELF,
                                         spaces,
                                         my_clob,
                                         chars_per_line);
        pljson_printer.htp_output_clob(my_clob, jsonp);
        dbms_lob.freetemporary(my_clob);
    END;

    /* json path */
    MEMBER FUNCTION path
    (
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) RETURN pljson_value AS
        cp pljson_list := SELF;
    BEGIN
        RETURN pljson_ext.get_json_value(pljson(cp), json_path, base);
    END path;

    /* json path_put */
    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      pljson_value,
        base      NUMBER DEFAULT 1
    ) AS
        objlist pljson;
        jp      pljson_list := pljson_ext.parsepath(json_path, base);
    BEGIN
        WHILE (jp.head().get_number() > self.count) LOOP
            self.append(pljson_value());
        END LOOP;
    
        objlist := pljson(SELF);
        pljson_ext.put(objlist, json_path, elem, base);
        SELF := objlist.get_values;
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      VARCHAR2,
        base      NUMBER DEFAULT 1
    ) AS
        objlist pljson;
        jp      pljson_list := pljson_ext.parsepath(json_path, base);
    BEGIN
        WHILE (jp.head().get_number() > self.count) LOOP
            self.append(pljson_value());
        END LOOP;
    
        objlist := pljson(SELF);
        pljson_ext.put(objlist, json_path, elem, base);
        SELF := objlist.get_values;
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      NUMBER,
        base      NUMBER DEFAULT 1
    ) AS
        objlist pljson;
        jp      pljson_list := pljson_ext.parsepath(json_path, base);
    BEGIN
        WHILE (jp.head().get_number() > self.count) LOOP
            self.append(pljson_value());
        END LOOP;
    
        objlist := pljson(SELF);
    
        IF (elem IS NULL) THEN
            pljson_ext.put(objlist, json_path, pljson_value, base);
        ELSE
            pljson_ext.put(objlist, json_path, elem, base);
        END IF;
        SELF := objlist.get_values;
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      binary_double,
        base      NUMBER DEFAULT 1
    ) AS
        objlist pljson;
        jp      pljson_list := pljson_ext.parsepath(json_path, base);
    BEGIN
        WHILE (jp.head().get_number() > self.count) LOOP
            self.append(pljson_value());
        END LOOP;
    
        objlist := pljson(SELF);
    
        IF (elem IS NULL) THEN
            pljson_ext.put(objlist, json_path, pljson_value, base);
        ELSE
            pljson_ext.put(objlist, json_path, elem, base);
        END IF;
        SELF := objlist.get_values;
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      BOOLEAN,
        base      NUMBER DEFAULT 1
    ) AS
        objlist pljson;
        jp      pljson_list := pljson_ext.parsepath(json_path, base);
    BEGIN
        WHILE (jp.head().get_number() > self.count) LOOP
            self.append(pljson_value());
        END LOOP;
    
        objlist := pljson(SELF);
        IF (elem IS NULL) THEN
            pljson_ext.put(objlist, json_path, pljson_value, base);
        ELSE
            pljson_ext.put(objlist, json_path, elem, base);
        END IF;
        SELF := objlist.get_values;
    END path_put;

    MEMBER PROCEDURE path_put
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        elem      pljson_list,
        base      NUMBER DEFAULT 1
    ) AS
        objlist pljson;
        jp      pljson_list := pljson_ext.parsepath(json_path, base);
    BEGIN
        WHILE (jp.head().get_number() > self.count) LOOP
            self.append(pljson_value());
        END LOOP;
    
        objlist := pljson(SELF);
        IF (elem IS NULL) THEN
            pljson_ext.put(objlist, json_path, pljson_value, base);
        ELSE
            pljson_ext.put(objlist, json_path, elem, base);
        END IF;
        SELF := objlist.get_values;
    END path_put;

    /* json path_remove */
    MEMBER PROCEDURE path_remove
    (
        SELF      IN OUT NOCOPY pljson_list,
        json_path VARCHAR2,
        base      NUMBER DEFAULT 1
    ) AS
        objlist pljson := pljson(SELF);
    BEGIN
        pljson_ext.remove(objlist, json_path, base);
        SELF := objlist.get_values;
    END path_remove;

    MEMBER FUNCTION to_json_value RETURN pljson_value AS
    BEGIN
        RETURN pljson_value(SELF);
    END;

END;
/
