DECLARE
    obj pljson := pljson('{
  "a" : true,
  "b" : [1,2,"3"],
  "c" : {
    "d" : [["array of array"], null, { "e": 7913 }]
  }
}');

BEGIN
    obj.print;

    DECLARE
        printme  NUMBER := NULL;
        temp     pljson_list;
        tempdata pljson_value;
        tempobj  pljson;
    BEGIN
        IF (obj.exist('b')) THEN
            IF (obj.get('b').is_array) THEN
                temp     := pljson_list(obj.get('b'));
                tempdata := temp.get(3); --return null on outofbounds
                IF (tempdata IS NOT NULL) THEN
                    IF (tempdata.is_number) THEN
                        printme := tempdata.get_number;
                    END IF;
                END IF;
            END IF;
        END IF;
        IF (printme IS NULL) THEN
            IF (obj.exist('c')) THEN
                tempdata := obj.get('c');
                IF (tempdata.is_object) THEN
                    tempobj := pljson(tempdata);
                    IF (tempobj.exist('d')) THEN
                        tempdata := tempobj.get('d');
                        IF (tempdata.is_array) THEN
                            temp     := pljson_list(tempdata);
                            tempdata := temp.get(3);
                            IF (tempdata.is_object) THEN
                                tempobj  := pljson(tempdata);
                                tempdata := tempobj.get('e');
                                IF (tempdata IS NOT NULL AND
                                   tempdata.is_number) THEN
                                    printme := tempdata.get_number;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
        IF (printme IS NOT NULL) THEN
            dbms_output.put_line(printme);
        END IF;
    END;

    DECLARE
        printme NUMBER := NULL;
    BEGIN
        printme := pljson_ext.get_string(obj, 'b[3]');
        do.pl(printme);
        printme := pljson_ext.get_number(obj, 'b[3]');
        do.pl(printme);
        IF (printme IS NULL) THEN
            printme := pljson_ext.get_number(obj, 'c.d[3].e');
        END IF;
        do.pl(printme);
    
    END;

    obj := pljson('{" a ": "String", "b": false, "c": null, "d":{}, "e":[],"f": "2009-09-01 00:00:00", "g":-789456}');
    dbms_output.put_line(pljson_ext.get_string(obj, ' a '));
    IF (pljson_ext.get_json_value(obj, 'c') IS NOT NULL) THEN
        dbms_output.put_line('null');
    END IF;
    dbms_output.put_line(pljson_ext.get_json(obj, 'd').to_char(FALSE));
    dbms_output.put_line(pljson_ext.get_json_list(obj, 'e').to_char);
    dbms_output.put_line(pljson_ext.get_date(obj, 'f'));
    dbms_output.put_line(pljson_ext.get_number(obj, 'g'));

END;
/
