create or replace package pljson_helper AS

/*
BEGIN
    pljson_helper.merge(pljson('{a:1, b:{a:null}, e:false}'),
                        pljson('{a:5,c:3, e:{}, b:{b:2}}')).print(FALSE);

    pljson_helper.join(pljson_list('[1,2,3]'), pljson_list('[4,5,6]')).print(FALSE);
    pljson_helper.keep(pljson('{a:1,b:2,c:3,d:4,e:5,f:6}'),
                       pljson_list('["a","f","c"]')).print(FALSE);
    pljson_helper.remove(pljson('{a:1,b:2,c:3,d:4,e:5,f:6}'),
                         pljson_list('["a","f","c"]')).print(FALSE);
END;
{"a":5,"b":{"a":null,"b":2},"e":{},"c":3}
[1,2,3,4,5,6]
{"a":1,"f":6,"c":3}
{"b":2,"d":4,"e":5}


*/

  function merge( p_a_json pljson, p_b_json pljson) return pljson;
  function join( p_a_list pljson_list, p_b_list pljson_list) return pljson_list;
  function keep( p_json pljson, p_keys pljson_list) return pljson;
  function remove( p_json pljson, p_keys pljson_list) return pljson;

  function equals(p_v1 pljson_value, p_v2 pljson_value, exact boolean default true) return boolean;
  function equals(p_v1 pljson_value, p_v2 pljson, exact boolean default true) return boolean;
  function equals(p_v1 pljson_value, p_v2 pljson_list, exact boolean default true) return boolean;
  function equals(p_v1 pljson_value, p_v2 number) return boolean;
  function equals(p_v1 pljson_value, p_v2 binary_double) return boolean;
  function equals(p_v1 pljson_value, p_v2 varchar2) return boolean;
  function equals(p_v1 pljson_value, p_v2 boolean) return boolean;
  function equals(p_v1 pljson_value, p_v2 clob) return boolean;
  function equals(p_v1 pljson, p_v2 pljson, exact boolean default true) return boolean;
  function equals(p_v1 pljson_list, p_v2 pljson_list, exact boolean default true) return boolean;


  function contains(p_v1 pljson, p_v2 pljson_value, exact boolean default false) return boolean;
  function contains(p_v1 pljson, p_v2 pljson, exact boolean default false) return boolean;
  function contains(p_v1 pljson, p_v2 pljson_list, exact boolean default false) return boolean;
  function contains(p_v1 pljson, p_v2 number, exact boolean default false) return boolean;
  function contains(p_v1 pljson, p_v2 binary_double, exact boolean default false) return boolean;
  function contains(p_v1 pljson, p_v2 varchar2, exact boolean default false) return boolean;
  function contains(p_v1 pljson, p_v2 boolean, exact boolean default false) return boolean;
  function contains(p_v1 pljson, p_v2 clob, exact boolean default false) return boolean;
  function contains(p_v1 pljson_list, p_v2 pljson_value, exact boolean default false) return boolean;
  function contains(p_v1 pljson_list, p_v2 pljson, exact boolean default false) return boolean;
  function contains(p_v1 pljson_list, p_v2 pljson_list, exact boolean default false) return boolean;
  function contains(p_v1 pljson_list, p_v2 number, exact boolean default false) return boolean;
  function contains(p_v1 pljson_list, p_v2 binary_double, exact boolean default false) return boolean;
  function contains(p_v1 pljson_list, p_v2 varchar2, exact boolean default false) return boolean;
  function contains(p_v1 pljson_list, p_v2 boolean, exact boolean default false) return boolean;
  function contains(p_v1 pljson_list, p_v2 clob, exact boolean default false) return boolean;

end pljson_helper;
/

CREATE OR REPLACE PACKAGE BODY pljson_helper AS

    --recursive merge
    FUNCTION MERGE
    (
        p_a_json pljson,
        p_b_json pljson
    ) RETURN pljson AS
        l_json      pljson;
        l_jv        pljson_value;
        l_indx      PLS_INTEGER;
        l_recursive pljson_value;
    BEGIN
        l_json := p_a_json;
        l_indx := p_b_json.json_data.first;
        LOOP
            EXIT WHEN l_indx IS NULL;
            l_jv := p_b_json.json_data(l_indx);
            IF (l_jv.is_object) THEN
                l_recursive := l_json.get(l_jv.mapname);
                IF (l_recursive IS NOT NULL AND l_recursive.is_object) THEN
                    l_json.put(l_jv.mapname,
                               MERGE(pljson(l_recursive), pljson(l_jv)));
                ELSE
                    l_json.put(l_jv.mapname, l_jv);
                END IF;
            ELSE
                l_json.put(l_jv.mapname, l_jv);
            END IF;
            l_indx := p_b_json.json_data.next(l_indx);
        END LOOP;
        RETURN l_json;
    END MERGE;

    -- join two lists
    FUNCTION JOIN
    (
        p_a_list pljson_list,
        p_b_list pljson_list
    ) RETURN pljson_list AS
        l_json_list pljson_list := p_a_list;
    BEGIN
        FOR indx IN 1 .. p_b_list.count LOOP
            l_json_list.append(p_b_list.get(indx));
        END LOOP;
        RETURN l_json_list;
    END JOIN;

    -- keep keys.
    FUNCTION keep
    (
        p_json pljson,
        p_keys pljson_list
    ) RETURN pljson AS
        l_json  pljson := pljson();
        mapname VARCHAR2(4000);
    BEGIN
        FOR i IN 1 .. p_keys.count LOOP
            mapname := p_keys.get(i).get_string;
            IF (p_json.exist(mapname)) THEN
                l_json.put(mapname, p_json.get(mapname));
            END IF;
        END LOOP;
        RETURN l_json;
    END keep;

    -- drop keys.
    FUNCTION remove
    (
        p_json pljson,
        p_keys pljson_list
    ) RETURN pljson AS
        l_json pljson := p_json;
    BEGIN
        FOR i IN 1 .. p_keys.count LOOP
            l_json.remove(p_keys.get(i).get_string);
        END LOOP;
        RETURN l_json;
    END remove;

    --equals functions

    FUNCTION equals
    (
        p_v1 pljson_value,
        p_v2 NUMBER
    ) RETURN BOOLEAN AS
    BEGIN
        IF (p_v2 IS NULL) THEN
            RETURN p_v1.is_null;
        END IF;

        IF (NOT p_v1.is_number) THEN
            RETURN FALSE;
        END IF;

        RETURN p_v2 = p_v1.get_number;
    END;

    FUNCTION equals
    (
        p_v1 pljson_value,
        p_v2 binary_double
    ) RETURN BOOLEAN AS
    BEGIN
        IF (p_v2 IS NULL) THEN
            RETURN p_v1.is_null;
        END IF;

        IF (NOT p_v1.is_number) THEN
            RETURN FALSE;
        END IF;

        RETURN p_v2 = p_v1.get_double;
    END;

    FUNCTION equals
    (
        p_v1 pljson_value,
        p_v2 BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        IF (p_v2 IS NULL) THEN
            RETURN p_v1.is_null;
        END IF;

        IF (NOT p_v1.is_bool) THEN
            RETURN FALSE;
        END IF;

        RETURN p_v2 = p_v1.get_bool;
    END;

    FUNCTION equals
    (
        p_v1 pljson_value,
        p_v2 VARCHAR2
    ) RETURN BOOLEAN AS
    BEGIN
        IF (p_v2 IS NULL) THEN
            RETURN(p_v1.is_null OR p_v1.get_string IS NULL);
        END IF;

        IF (NOT p_v1.is_string) THEN
            RETURN FALSE;
        END IF;

        RETURN p_v2 = p_v1.get_string;
    END;

    FUNCTION equals
    (
        p_v1 pljson_value,
        p_v2 CLOB
    ) RETURN BOOLEAN AS
        my_clob CLOB;
        res     BOOLEAN;
    BEGIN
        IF (p_v2 IS NULL) THEN
            RETURN p_v1.is_null;
        END IF;

        IF (NOT p_v1.is_string) THEN
            RETURN FALSE;
        END IF;

        my_clob := empty_clob();
        dbms_lob.createtemporary(my_clob, TRUE);
        p_v1.get_string(my_clob);

        res := dbms_lob.compare(p_v2, my_clob) = 0;
        dbms_lob.freetemporary(my_clob);
        RETURN res;
    END;

    FUNCTION equals
    (
        p_v1  pljson_value,
        p_v2  pljson_value,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        IF (p_v2 IS NULL OR p_v2.is_null) THEN
            RETURN(p_v1 IS NULL OR p_v1.is_null);
        END IF;

        IF (p_v2.is_number) THEN
            RETURN equals(p_v1, p_v2.get_number);
        END IF;
        IF (p_v2.is_bool) THEN
            RETURN equals(p_v1, p_v2.get_bool);
        END IF;
        IF (p_v2.is_object) THEN
            RETURN equals(p_v1, pljson(p_v2), exact);
        END IF;
        IF (p_v2.is_array) THEN
            RETURN equals(p_v1, pljson_list(p_v2), exact);
        END IF;
        IF (p_v2.is_string) THEN
            IF (p_v2.extended_str IS NULL) THEN
                RETURN equals(p_v1, p_v2.get_string);
            ELSE
                DECLARE
                    my_clob CLOB;
                    res     BOOLEAN;
                BEGIN
                    my_clob := empty_clob();
                    dbms_lob.createtemporary(my_clob, TRUE);
                    p_v2.get_string(my_clob);
                    res := equals(p_v1, my_clob);
                    dbms_lob.freetemporary(my_clob);
                    RETURN res;
                END;
            END IF;
        END IF;

        RETURN FALSE; --should never happen
    END;

    FUNCTION equals
    (
        p_v1  pljson_value,
        p_v2  pljson_list,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
        cmp pljson_list;
        res BOOLEAN := TRUE;
    BEGIN

        IF (p_v2 IS NULL) THEN
            RETURN p_v1.is_null;
        END IF;

        IF (NOT p_v1.is_array) THEN
            RETURN FALSE;
        END IF;

        cmp := pljson_list(p_v1);
        IF (cmp.count != p_v2.count AND exact) THEN
            RETURN FALSE;
        END IF;

        IF (exact) THEN
            FOR i IN 1 .. cmp.count LOOP
                res := equals(cmp.get(i), p_v2.get(i), exact);
                IF (NOT res) THEN
                    RETURN res;
                END IF;
            END LOOP;
        ELSE
            IF (p_v2.count > cmp.count) THEN
                RETURN FALSE;
            END IF;

            FOR x IN 0 .. (cmp.count - p_v2.count) LOOP
                FOR i IN 1 .. p_v2.count LOOP
                    res := equals(cmp.get(x + i), p_v2.get(i), exact);
                    IF (NOT res) THEN
                        GOTO next_index;
                    END IF;
                END LOOP;
                RETURN TRUE;

                <<next_index>>
                NULL;
            END LOOP;
            RETURN FALSE; --no match

        END IF;

        RETURN res;
    END;

    FUNCTION equals
    (
        p_v1  pljson_value,
        p_v2  pljson,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
        cmp pljson;
        res BOOLEAN := TRUE;
    BEGIN

        IF (p_v2 IS NULL) THEN
            RETURN p_v1.is_null;
        END IF;

        IF (NOT p_v1.is_object) THEN
            RETURN FALSE;
        END IF;

        cmp := pljson(p_v1);

        IF (cmp.count != p_v2.count AND exact) THEN
            RETURN FALSE;
        END IF;

        DECLARE
            k1        pljson_list := p_v2.get_keys;
            key_index NUMBER;
        BEGIN
            FOR i IN 1 .. k1.count LOOP
                key_index := cmp.index_of(k1.get(i).get_string);
                IF (key_index = -1) THEN
                    RETURN FALSE;
                END IF;
                IF (exact) THEN
                    IF (NOT equals(p_v2.get(i), cmp.get(key_index), TRUE)) THEN
                        RETURN FALSE;
                    END IF;
                ELSE
                    DECLARE
                        v1 pljson_value := cmp.get(key_index);
                        v2 pljson_value := p_v2.get(i);
                    BEGIN

                        IF (v1.is_object AND v2.is_object) THEN
                            IF (NOT equals(v1, v2, FALSE)) THEN
                                RETURN FALSE;
                            END IF;
                        ELSIF (v1.is_array AND v2.is_array) THEN
                            IF (NOT equals(v1, v2, FALSE)) THEN
                                RETURN FALSE;
                            END IF;
                        ELSE
                            IF (NOT equals(v1, v2, TRUE)) THEN
                                RETURN FALSE;
                            END IF;
                        END IF;
                    END;

                END IF;
            END LOOP;
        END;

        RETURN TRUE;
    END;

    FUNCTION equals
    (
        p_v1  pljson,
        p_v2  pljson,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN equals(p_v1.to_json_value, p_v2, exact);
    END;

    FUNCTION equals
    (
        p_v1  pljson_list,
        p_v2  pljson_list,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN equals(p_v1.to_json_value, p_v2, exact);
    END;

    --contain
    FUNCTION contains
    (
        p_v1  pljson,
        p_v2  pljson_value,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
        v_values pljson_list;
    BEGIN
        IF (equals(p_v1.to_json_value, p_v2, exact)) THEN
            RETURN TRUE;
        END IF;

        v_values := p_v1.get_values;

        FOR i IN 1 .. v_values.count LOOP
            DECLARE
                v_val pljson_value := v_values.get(i);
            BEGIN
                IF (v_val.is_object) THEN
                    IF (contains(pljson(v_val), p_v2, exact)) THEN
                        RETURN TRUE;
                    END IF;
                END IF;
                IF (v_val.is_array) THEN
                    IF (contains(pljson_list(v_val), p_v2, exact)) THEN
                        RETURN TRUE;
                    END IF;
                END IF;

                IF (equals(v_val, p_v2, exact)) THEN
                    RETURN TRUE;
                END IF;
            END;

        END LOOP;

        RETURN FALSE;
    END;

    FUNCTION contains
    (
        p_v1  pljson_list,
        p_v2  pljson_value,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        IF (equals(p_v1.to_json_value, p_v2, exact)) THEN
            RETURN TRUE;
        END IF;

        FOR i IN 1 .. p_v1.count LOOP
            DECLARE
                v_val pljson_value := p_v1.get(i);
            BEGIN
                IF (v_val.is_object) THEN
                    IF (contains(pljson(v_val), p_v2, exact)) THEN
                        RETURN TRUE;
                    END IF;
                END IF;
                IF (v_val.is_array) THEN
                    IF (contains(pljson_list(v_val), p_v2, exact)) THEN
                        RETURN TRUE;
                    END IF;
                END IF;

                IF (equals(v_val, p_v2, exact)) THEN
                    RETURN TRUE;
                END IF;
            END;

        END LOOP;

        RETURN FALSE;
    END;

    FUNCTION contains
    (
        p_v1  pljson,
        p_v2  pljson,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, p_v2.to_json_value, exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson,
        p_v2  pljson_list,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, p_v2.to_json_value, exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson,
        p_v2  NUMBER,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson,
        p_v2  binary_double,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson,
        p_v2  VARCHAR2,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson,
        p_v2  BOOLEAN,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson,
        p_v2  CLOB,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;

    FUNCTION contains
    (
        p_v1  pljson_list,
        p_v2  pljson,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, p_v2.to_json_value, exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson_list,
        p_v2  pljson_list,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, p_v2.to_json_value, exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson_list,
        p_v2  NUMBER,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson_list,
        p_v2  binary_double,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson_list,
        p_v2  VARCHAR2,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson_list,
        p_v2  BOOLEAN,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;
    FUNCTION contains
    (
        p_v1  pljson_list,
        p_v2  CLOB,
        exact BOOLEAN
    ) RETURN BOOLEAN AS
    BEGIN
        RETURN contains(p_v1, pljson_value(p_v2), exact);
    END;

END pljson_helper;
/


/**

DECLARE
    v1 pljson := pljson('{a:34, b:true, a2:{a1:2,a3:{}}, c:{a:[1,2,3,4,5,true]}, g:3}');
    v2 pljson := pljson('{a:34, b:true, a2:{a1:2}}');

BEGIN
    IF (pljson_helper.contains(v1, v2)) THEN
        do.pl('contains!');
    ELSE
        do.pl('!!!');
    END IF;
END;
**/

