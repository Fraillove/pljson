create or replace type pljson_value_array as table of pljson_value;
/

CREATE OR REPLACE TYPE pljson_value force AS OBJECT
(

    typeval NUMBER(1), /* 1 = object,
                        2 = array , 
                        3 = string, 
                        4 = number, 
                        5 = bool  , 
                        6 = null */

    str               VARCHAR2(32767),
    num               NUMBER, /* store 1 as true, 0 as false */
    num_double        binary_double, -- both num and num_double are set, there is never exception (until Oracle 12c)
    num_repr_number_p VARCHAR2(1),
    num_repr_double_p VARCHAR2(1),
    object_or_array   pljson_element, /* object or array in here */
    extended_str      CLOB,

/* mapping */
    mapname VARCHAR2(4000),
    mapindx NUMBER(32),

    CONSTRUCTOR FUNCTION pljson_value(elem pljson_element)
        RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION pljson_value
    (
        str VARCHAR2,
        esc BOOLEAN DEFAULT TRUE
    ) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION pljson_value
    (
        str CLOB,
        esc BOOLEAN DEFAULT TRUE
    ) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION pljson_value(num NUMBER) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION pljson_value(num_double binary_double)
        RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION pljson_value(b BOOLEAN) RETURN SELF AS RESULT,
    CONSTRUCTOR FUNCTION pljson_value RETURN SELF AS RESULT,

    MEMBER FUNCTION get_element RETURN pljson_element,

    STATIC FUNCTION makenull RETURN pljson_value,

    MEMBER FUNCTION get_type RETURN VARCHAR2,

    MEMBER FUNCTION get_string
    (
        max_byte_size NUMBER DEFAULT NULL,
        max_char_size NUMBER DEFAULT NULL
    ) RETURN VARCHAR2,

    MEMBER PROCEDURE get_string
    (
        SELF IN pljson_value,
        buf  IN OUT NOCOPY CLOB
    ),

    MEMBER FUNCTION get_number RETURN NUMBER,

    MEMBER FUNCTION get_double RETURN binary_double,

    MEMBER FUNCTION get_bool RETURN BOOLEAN,

    MEMBER FUNCTION get_null RETURN VARCHAR2,

    MEMBER FUNCTION is_object RETURN BOOLEAN,

    MEMBER FUNCTION is_array RETURN BOOLEAN,

    MEMBER FUNCTION is_string RETURN BOOLEAN,

    MEMBER FUNCTION is_number RETURN BOOLEAN,

    MEMBER FUNCTION is_bool RETURN BOOLEAN,

    MEMBER FUNCTION is_null RETURN BOOLEAN,

    MEMBER FUNCTION is_number_repr_number RETURN BOOLEAN,

    MEMBER FUNCTION is_number_repr_double RETURN BOOLEAN,

    MEMBER PROCEDURE parse_number(str VARCHAR2),

    MEMBER FUNCTION number_tostring RETURN VARCHAR2,

/* Output methods */
    MEMBER FUNCTION to_char
    (
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2,
    MEMBER PROCEDURE to_clob
    (
        SELF           IN pljson_value,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    ),
    MEMBER PROCEDURE print
    (
        SELF           IN pljson_value,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    ), --32512 is maximum
    MEMBER PROCEDURE htp
    (
        SELF           IN pljson_value,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    ),

    MEMBER FUNCTION value_of
    (
        SELF          IN pljson_value,
        max_byte_size NUMBER DEFAULT NULL,
        max_char_size NUMBER DEFAULT NULL
    ) RETURN VARCHAR2

)
NOT FINAL;
/

CREATE OR REPLACE TYPE BODY pljson_value AS

    CONSTRUCTOR FUNCTION pljson_value(elem pljson_element)
        RETURN SELF AS RESULT AS
    BEGIN
        CASE
            WHEN elem IS OF(pljson) THEN
                self.typeval := 1;
            WHEN elem IS OF(pljson_list) THEN
                self.typeval := 2;
            ELSE
                raise_application_error(-20102,
                                        'PLJSON_VALUE init error (PLJSON or PLJSON_LIST allowed)');
        END CASE;
        self.object_or_array := elem;
        IF (self.object_or_array IS NULL) THEN
            self.typeval := 6;
        END IF;
    
        RETURN;
    END pljson_value;

    CONSTRUCTOR FUNCTION pljson_value
    (
        str VARCHAR2,
        esc BOOLEAN DEFAULT TRUE
    ) RETURN SELF AS RESULT AS
    BEGIN
        self.typeval := 3;
        IF (esc) THEN
            self.num := 1;
        ELSE
            self.num := 0;
        END IF; --message to pretty printer
        self.str := str;
        RETURN;
    END pljson_value;

    CONSTRUCTOR FUNCTION pljson_value
    (
        str CLOB,
        esc BOOLEAN DEFAULT TRUE
    ) RETURN SELF AS RESULT AS
        amount NUMBER := 5000; /* for Unicode text, varchar2 'self.str' not exceed 5000 chars, does not limit size of data */
    BEGIN
        self.typeval := 3;
        IF (esc) THEN
            self.num := 1;
        ELSE
            self.num := 0;
        END IF; --message to pretty printer
        IF (dbms_lob.getlength(str) > amount) THEN
            extended_str := str;
        END IF;
        IF dbms_lob.getlength(str) > 0 THEN
            dbms_lob.read(str, amount, 1, self.str);
        END IF;
        RETURN;
    END pljson_value;

    CONSTRUCTOR FUNCTION pljson_value(num NUMBER) RETURN SELF AS RESULT AS
    BEGIN
        self.typeval           := 4;
        self.num               := num;
        self.num_repr_number_p := 't';
        self.num_double        := num;
        IF (to_number(self.num_double) = self.num) THEN
            self.num_repr_double_p := 't';
        ELSE
            self.num_repr_double_p := 'f';
        END IF;
        IF (self.num IS NULL) THEN
            self.typeval := 6;
        END IF;
        RETURN;
    END pljson_value;

    CONSTRUCTOR FUNCTION pljson_value(num_double binary_double)
        RETURN SELF AS RESULT AS
    BEGIN
        self.typeval           := 4;
        self.num_double        := num_double;
        self.num_repr_double_p := 't';
        self.num               := num_double;
        IF (to_binary_double(self.num) = self.num_double) THEN
            self.num_repr_number_p := 't';
        ELSE
            self.num_repr_number_p := 'f';
        END IF;
        IF (self.num_double IS NULL) THEN
            self.typeval := 6;
        END IF;
        RETURN;
    END pljson_value;

    CONSTRUCTOR FUNCTION pljson_value(b BOOLEAN) RETURN SELF AS RESULT AS
    BEGIN
        self.typeval := 5;
        self.num     := 0;
        IF (b) THEN
            self.num := 1;
        END IF;
        IF (b IS NULL) THEN
            self.typeval := 6;
        END IF;
        RETURN;
    END pljson_value;

    CONSTRUCTOR FUNCTION pljson_value RETURN SELF AS RESULT AS
    BEGIN
        self.typeval := 6; /* for JSON null */
        RETURN;
    END pljson_value;

    MEMBER FUNCTION get_element RETURN pljson_element AS
    BEGIN
        IF (self.typeval IN (1, 2)) THEN
            RETURN self.object_or_array;
        END IF;
        RETURN NULL;
    END get_element;

    STATIC FUNCTION makenull RETURN pljson_value AS
    BEGIN
        RETURN pljson_value;
    END makenull;

    MEMBER FUNCTION get_type RETURN VARCHAR2 AS
    BEGIN
        CASE self.typeval
            WHEN 1 THEN
                RETURN 'object';
            WHEN 2 THEN
                RETURN 'array';
            WHEN 3 THEN
                RETURN 'string';
            WHEN 4 THEN
                RETURN 'number';
            WHEN 5 THEN
                RETURN 'bool';
            WHEN 6 THEN
                RETURN 'null';
        END CASE;
    
        RETURN 'unknown type';
    END get_type;

    MEMBER FUNCTION get_string
    (
        max_byte_size NUMBER DEFAULT NULL,
        max_char_size NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 AS
    BEGIN
        IF (self.typeval = 3) THEN
            IF (max_byte_size IS NOT NULL) THEN
                RETURN substrb(self.str, 1, max_byte_size);
            ELSIF (max_char_size IS NOT NULL) THEN
                RETURN substr(self.str, 1, max_char_size);
            ELSE
                RETURN self.str;
            END IF;
        END IF;
        RETURN NULL;
    END get_string;

    MEMBER PROCEDURE get_string
    (
        SELF IN pljson_value,
        buf  IN OUT NOCOPY CLOB
    ) AS
    BEGIN
        IF (self.typeval = 3) THEN
            IF (extended_str IS NOT NULL) THEN
                dbms_lob.copy(buf,
                              extended_str,
                              dbms_lob.getlength(extended_str));
            ELSE
                dbms_lob.writeappend(buf, length(self.str), self.str);
            END IF;
        END IF;
    END get_string;

    MEMBER FUNCTION get_number RETURN NUMBER AS
    BEGIN
        IF (self.typeval = 4) THEN
            RETURN self.num;
        END IF;
        RETURN NULL;
    END get_number;

    MEMBER FUNCTION get_double RETURN binary_double AS
    BEGIN
        IF (self.typeval = 4) THEN
            RETURN self.num_double;
        END IF;
        RETURN NULL;
    END get_double;

    MEMBER FUNCTION get_bool RETURN BOOLEAN AS
    BEGIN
        IF (self.typeval = 5) THEN
            RETURN self.num = 1;
        END IF;
        RETURN NULL;
    END get_bool;

    MEMBER FUNCTION get_null RETURN VARCHAR2 AS
    BEGIN
        IF (self.typeval = 6) THEN
            RETURN 'null';
        END IF;
        RETURN NULL;
    END get_null;

    MEMBER FUNCTION is_object RETURN BOOLEAN AS
    BEGIN
        RETURN self.typeval = 1;
    END;
    MEMBER FUNCTION is_array RETURN BOOLEAN AS
    BEGIN
        RETURN self.typeval = 2;
    END;
    MEMBER FUNCTION is_string RETURN BOOLEAN AS
    BEGIN
        RETURN self.typeval = 3;
    END;
    MEMBER FUNCTION is_number RETURN BOOLEAN AS
    BEGIN
        RETURN self.typeval = 4;
    END;
    MEMBER FUNCTION is_bool RETURN BOOLEAN AS
    BEGIN
        RETURN self.typeval = 5;
    END;
    MEMBER FUNCTION is_null RETURN BOOLEAN AS
    BEGIN
        RETURN self.typeval = 6;
    END;

    /* return true if 'number' is representable by number */
    MEMBER FUNCTION is_number_repr_number RETURN BOOLEAN IS
    BEGIN
        IF self.typeval != 4 THEN
            RETURN FALSE;
        END IF;
        RETURN(num_repr_number_p = 't');
    END;

    /* return true if 'number' is representable by binary_double */
    MEMBER FUNCTION is_number_repr_double RETURN BOOLEAN IS
    BEGIN
        IF self.typeval != 4 THEN
            RETURN FALSE;
        END IF;
        RETURN(num_repr_double_p = 't');
    END;

    MEMBER PROCEDURE parse_number(str VARCHAR2) IS
    BEGIN
        IF self.typeval != 4 THEN
            RETURN;
        END IF;
        self.num               := to_number(str);
        self.num_repr_number_p := 't';
        self.num_double        := to_binary_double(str);
        self.num_repr_double_p := 't';
        IF (to_binary_double(self.num) != self.num_double) THEN
            self.num_repr_number_p := 'f';
        END IF;
        IF (to_number(self.num_double) != self.num) THEN
            self.num_repr_double_p := 'f';
        END IF;
    END parse_number;

    -- centralized toString to use everywhere else and replace code in pljson_printer
    MEMBER FUNCTION number_tostring RETURN VARCHAR2 IS
        num        NUMBER;
        num_double binary_double;
        buf        VARCHAR2(4000);
    BEGIN
        /* unrolled, instead of using two nested fuctions for speed */
        IF (self.num_repr_number_p = 't') THEN
            num := self.num;
            IF (num > 1e127d) THEN
                RETURN '1e309'; -- json representation of infinity !?
            END IF;
            IF (num < -1e127d) THEN
                RETURN '-1e309'; -- json representation of infinity !?
            END IF;
            buf := standard.to_char(num,
                                    'TM9',
                                    'NLS_NUMERIC_CHARACTERS=''.,''');
            IF (-1 < num AND num < 0 AND substr(buf, 1, 2) = '-.') THEN
                buf := '-0' || substr(buf, 2);
            ELSIF (0 < num AND num < 1 AND substr(buf, 1, 1) = '.') THEN
                buf := '0' || buf;
            END IF;
            RETURN buf;
        ELSE
            num_double := self.num_double;
            IF (num_double = +binary_double_infinity) THEN
                RETURN '1e309'; -- json representation of infinity !?
            END IF;
            IF (num_double = -binary_double_infinity) THEN
                RETURN '-1e309'; -- json representation of infinity !?
            END IF;
            buf := standard.to_char(num_double,
                                    'TM9',
                                    'NLS_NUMERIC_CHARACTERS=''.,''');
            IF (-1 < num_double AND num_double < 0 AND
               substr(buf, 1, 2) = '-.') THEN
                buf := '-0' || substr(buf, 2);
            ELSIF (0 < num_double AND num_double < 1 AND
                  substr(buf, 1, 1) = '.') THEN
                buf := '0' || buf;
            END IF;
            RETURN buf;
        END IF;
    END number_tostring;

    /* Output methods */
    MEMBER FUNCTION to_char
    (
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 0
    ) RETURN VARCHAR2 AS
    BEGIN
        IF (spaces IS NULL) THEN
            RETURN pljson_printer.pretty_print_any(SELF,
                                                   line_length => chars_per_line);
        ELSE
            RETURN pljson_printer.pretty_print_any(SELF,
                                                   spaces,
                                                   line_length => chars_per_line);
        END IF;
    END;

    MEMBER PROCEDURE to_clob
    (
        SELF           IN pljson_value,
        buf            IN OUT NOCOPY CLOB,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        erase_clob     BOOLEAN DEFAULT TRUE
    ) AS
    BEGIN
        IF (spaces IS NULL) THEN
            pljson_printer.pretty_print_any(SELF,
                                            FALSE,
                                            buf,
                                            line_length => chars_per_line,
                                            erase_clob  => erase_clob);
        ELSE
            pljson_printer.pretty_print_any(SELF,
                                            spaces,
                                            buf,
                                            line_length => chars_per_line,
                                            erase_clob  => erase_clob);
        END IF;
    END;

    MEMBER PROCEDURE print
    (
        SELF           IN pljson_value,
        spaces         BOOLEAN DEFAULT TRUE,
        chars_per_line NUMBER DEFAULT 8192,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
        --32512 is the real maximum in sqldeveloper
        my_clob CLOB;
    BEGIN
        my_clob := empty_clob();
        dbms_lob.createtemporary(my_clob, TRUE);
        pljson_printer.pretty_print_any(SELF,
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
        SELF           IN pljson_value,
        spaces         BOOLEAN DEFAULT FALSE,
        chars_per_line NUMBER DEFAULT 0,
        jsonp          VARCHAR2 DEFAULT NULL
    ) AS
        my_clob CLOB;
    BEGIN
        my_clob := empty_clob();
        dbms_lob.createtemporary(my_clob, TRUE);
        pljson_printer.pretty_print_any(SELF,
                                        spaces,
                                        my_clob,
                                        chars_per_line);
        pljson_printer.htp_output_clob(my_clob, jsonp);
        dbms_lob.freetemporary(my_clob);
    END;

    MEMBER FUNCTION value_of
    (
        SELF          IN pljson_value,
        max_byte_size NUMBER DEFAULT NULL,
        max_char_size NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 AS
    BEGIN
        CASE self.typeval
            WHEN 1 THEN
                RETURN 'json object';
            WHEN 2 THEN
                RETURN 'json array';
            WHEN 3 THEN
                RETURN self.get_string(max_byte_size, max_char_size);
            WHEN 4 THEN
                RETURN self.get_number();
            WHEN 5 THEN
                IF (self.get_bool()) THEN
                    RETURN 'true';
                ELSE
                    RETURN 'false';
                END IF;
            ELSE
                RETURN NULL;
        END CASE;
    END;

END;
/
