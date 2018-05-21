###pljson 基本数据类型
|类型   |用途      |对应关系      |
| ---- | ---- | ---- |
|   **pljson**   | 表示 json 对象    | json 字符串  `{`和`}`之间的内容 |
|   **pljson_list**   | 表示 json 数组,是 json 对象或普通变量类型值的集合      | json 字符串  `[`和`]`之间的内容     |
|   **pljson_value**   | 表示 json 对象中的值.可以是<br/>1. `pljson`<br/>2. `pljson_list`<br/>3. `string`<br/>4. `number`<br/>5. `bool`<br/>6. `null`<br/> |对应 json 对象中键值对中的值      |

![JSONTYPE.png](https://i.loli.net/2018/05/18/5afe4d2244a51.png)

#####实际操作示例(mis 测试环境执行)

```plsql
DECLARE
    obj         pljson := pljson();
    json_object pljson;
BEGIN
    obj         := pljson('{"value":{"weight":"spots","Invalid spots":"Invalid"}}');
    json_object := pljson_ext.get_json(obj, 'value');
    json_object.print;

    do.pl(json_object.to_char);
END;



DECLARE
    json_obj  pljson := pljson();
    json_list pljson_list := pljson_list();
BEGIN
    json_list.append(1);
    json_list.append(2);
    json_list.append(3);

    json_obj.put('foo', 'bar');
    json_obj.put('baz', 42);
    json_obj.put('foobar', json_list);
    json_obj.print;
END;


DECLARE
    json_data2 pljson;
    json_data  pljson := pljson('{   "foo": "bar",   "list": [     {"key": "value1"},     {"key": "value2"}   ] }');
    list_value pljson_list;
BEGIN
    list_value := pljson_ext.get_json_list(json_data, 'list');

    dbms_output.put_line('Count = ' || list_value.count);

    FOR i IN 1 .. list_value.count LOOP
        pljson(list_value.get(i)).get('key').print;
    END LOOP;
END;





DECLARE
    my_json  pljson := pljson('{"TR,A" : "OK" }');
    my_json1 pljson := pljson('{ "T": { "R": { "TR,A": "OK" } } }');
BEGIN
    dbms_output.put_line(my_json.get('TR,A').to_char);
    dbms_output.put_line(my_json1.path(q'{T.R['TR,A']}').to_char);
END;



DECLARE
    l_geo_data CLOB := '{
  "bounds" : {
    "northeast" : {
      "lat" : 44.9483849,
      "lng" : -93.1261959
    },
    "southwest" : {
      "lat" : 44.9223829,
      "lng" : -93.200307
    }
  },
  "location" : {
    "lat" : 44.9330076,
    "lng" : -93.16290629999999
  },
  "location_type" : "APPROXIMATE",
  "viewport" : {
    "northeast" : {
      "lat" : 44.9483849,
      "lng" : -93.1261959
    },
    "southwest" : {
      "lat" : 44.9223829,
      "lng" : -93.200307
    }
  }
}';

    l_geo_data_json  PLjson;
    l_bounds_json    PLjson;
    l_northeast_json PLjson;
    l_southwest_json PLjson;

BEGIN
    l_geo_data_json := PLjson(l_geo_data);

    dbms_output.put_line('-- one way to do it...');
    l_bounds_json := PLjson(l_geo_data_json.get('bounds'));

    l_northeast_json := PLjson(l_bounds_json.get('northeast'));
    dbms_output.put_line('bounds.northeast.lat:' || l_northeast_json.get('lat')
                         .get_number);
    dbms_output.put_line('bounds.northeast.lng:' || l_northeast_json.get('lng')
                         .get_number);

    l_southwest_json := PLjson(l_bounds_json.get('southwest'));
    dbms_output.put_line('bounds.southwest.lat:' || l_southwest_json.get('lat')
                         .get_number);
    dbms_output.put_line('bounds.southwest.lng:' || l_southwest_json.get('lng')
                         .get_number);

    dbms_output.new_line();
    dbms_output.put_line('-- another way is to use path method if you dont care about any specific attribute but just the one you need...');
    dbms_output.put_line('bounds.northeast.lat:' || l_geo_data_json.path('bounds.northeast.lat')
                         .get_number);
    dbms_output.put_line('bounds.southwest.lat:' || l_geo_data_json.path('bounds.southwest.lat')
                         .get_number);

    dbms_output.new_line();
    dbms_output.put_line('-- getting the location_type');
    dbms_output.put_line('location_type:' || l_geo_data_json.get('location_type')
                         .get_string);

END;





DECLARE
    obj   pljson := pljson();
    obj_1 pljson := pljson();
    arr   pljson_list := pljson_list();
    val   NUMBER;
BEGIN
    obj := pljson('{
  "Order" : {
    "no" : 1,
    "batch" : 2,
    "id" : 3,
    "quantity" : 10,
    "sm_pack" : [{
      "no" : 10,
      "id" : 1010,
      "quantity" : 2
    }, {
      "no" : 11,
      "id" : 1040,
      "quantity" : 8
    }],
    "sm_size" : [{
      "no" : 10,
      "id" : 1010,
      "quantity" : 2
    }, {
      "no" : 11,
      "id" : 1040,
      "quantity" : 8
    }]
  }
}');
    obj_1 := pljson(obj.get('Order'));

    arr := pljson_list(obj_1.get('sm_pack'));
    arr.print;
    --or
    arr := pljson_list(pljson(obj.get('Order')).get('sm_pack'));
    arr.print;

    val := pljson_ext.get_number(pljson(arr.get(2)), 'id');
    dbms_output.put_line(val);

END;
/




declare
  json_obj PLjson := PLjson('{}');
  list PLjson_list;
begin
  list := json_obj.get_keys;

  if list.count = 0 then
    dbms_output.put_line('Empty object');
  else
    dbms_output.put_line('Non-empty object');
  end if;
end;




DECLARE
    a    CLOB;
    obj  pljson;
BEGIN
    SELECT pljson_util_pkg.sql_to_jsonclob('select * from emp') INTO a FROM dual;
    dbms_output.enable(NULL);
    obj := pljson(a);
    obj.print;
END;




DECLARE
    ajsonobj   pljson;
    ajsonarray pljson_list;
    ajsonvalue pljson_value;
BEGIN
    ajsonobj := pljson('{"key1":"1","key2":"2"}');
    ajsonobj.print;
    --json转json_list
    ajsonarray := ajsonobj.get_values;
    ajsonarray.print;
    --json转json_value
    ajsonvalue := ajsonobj.to_json_value;
    ajsonvalue.print;

    ajsonarray := pljson_list('[{"key1":"1","key2":"2"},{"key1":"a","key2":"b"}]');
    --json_list转json_value
    ajsonvalue := ajsonarray.to_json_value;
    ajsonvalue.print;
END;
  

DECLARE
    ajsonobj pljson;
    anotherjsonobj pljson;
    ajsonarray pljson_list;
    anotherjsonarray pljson_list;
    ajsonvalue pljson_value;

BEGIN
    ajsonobj := pljson('{"key1":["1","2","3"],"key2":{"key2A":"a","key2B":"b"}}');
    anotherjsonobj := pljson();
    ajsonarray := pljson_list('[5,6,7]');
    anotherjsonarray := pljson_list();

    ajsonvalue := ajsonobj.get('key2');

    anotherjsonobj := pljson(ajsonvalue);

    ajsonvalue := ajsonobj.get('key1');

    anotherjsonarray := pljson_list(ajsonvalue);
    dbms_output.put_line(ajsonobj.to_char);
    dbms_output.put_line(anotherjsonobj.to_char);
    dbms_output.put_line(ajsonarray.to_char);
    dbms_output.put_line(anotherjsonarray.to_char);
END;





DECLARE
    ajsonobj pljson;
    ajsonvalue pljson_value;
BEGIN
    ajsonobj := pljson('{"key1":"1","key2":{"key2A":"a","key2B":"b"}}');
    ajsonvalue := ajsonobj.get('key1');
    dbms_output.put_line(ajsonvalue.get_string);
    ajsonobj.put('key3', 999);
    ajsonobj.print;
    ajsonobj.remove('key2');
    ajsonobj.print;
END;




--JSON对象key的遍历
DECLARE
    ajsonobj pljson;
    keys pljson_list;
BEGIN
    ajsonobj := pljson('{"key1":"1",
    "key2":{"key2A":"a","key2B":"b"}}');
    --通过get_keys方法获取关键字集合，类型为json_list
    keys := ajsonobj.get_keys;
    --遍历关键字集合
    FOR i IN 1 .. keys.count LOOP
        dbms_output.put_line(ajsonobj.get(keys.get(i).get_string).to_char);
    END LOOP;
END;



--JSON数组基本操作示例
DECLARE
    ajsonarray pljson_list;
    ajsonvalue pljson_value;
BEGIN
    ajsonarray := pljson_list('[{"key1":"1","key2":"2"},{"key1":"a","key2":"b"}]');
    --可以通过get方法获取指定索引位置的元素，返回值类型为json_value
    ajsonvalue := ajsonarray.get(1);
    --输出为{"key1":"1","key2":"2"}
    ajsonvalue.print;
    --可以通过append方法向json数组添加新元素
    ajsonarray.append(pljson('{"key1":"A","key2":"B"}').to_json_value);
    --输出为[{"key1":"1","key2":"2"},{"key1":"a","key2":"b"},
    --{"key1":"A","key2":"B"}]
    ajsonarray.print;
    --可以通过remove方法从json数组移除元素
    ajsonarray.remove(2);
    --输出为[{"key1":"1","key2":"2"},{"key1":"A","key2":"B"}]
    ajsonarray.print;
    --可以通过replace方法替换json数组中指定位置的元素,参数类型为json_value
    ajsonarray.replace(1, pljson('{"key1":"m","key2":"n"}').to_json_value);
    --输出为[{"key1":"m","key2":"n"},{"key1":"A","key2":"B"}]
    ajsonarray.print;
END;




  --JSON数组的遍历示例
DECLARE
    --json数组
    ajsonarray pljson_list;
BEGIN
    ajsonarray := pljson_list('[{"key1":"1","key2":"2"},
    {"key1":"a","key2":"b"}]');
    --遍历数组中各元素
    FOR i IN 1 .. ajsonarray.count LOOP
        ajsonarray.get(i).print;
    END LOOP;
END;




DECLARE
    --json对象
    ajsonobj pljson;
    --源文本
    srcclob CLOB;
    --目标文本
    desclob CLOB;
BEGIN
    desclob := empty_clob();
    dbms_lob.createtemporary(desclob, TRUE);
    --假设json对象key1的值是个大文本
    ajsonobj := pljson('{"key1":"a long long text..."}');
   --do.pl(ajsonobj.get('key1').to_char);
    --直接用pljson存入会在clob值的两侧有双引号
    srcclob := empty_clob();
    dbms_lob.createtemporary(srcclob, TRUE);
    ajsonobj.get('key1').to_clob(srcclob, TRUE);
    dbms_lob.copy(desclob, srcclob, dbms_lob.getlength(srcclob) - 2, 1, 2);
    dbms_lob.freetemporary(srcclob);

    dbms_output.put_line(desclob);
    dbms_lob.freetemporary(desclob);
END;



--JSON PATH示例
DECLARE
    ajsonobj pljson;
    anotherjsonobj pljson;
BEGIN
    ajsonobj := pljson('{"Level1Key1":[{"Level2Key1":"a"},{"Level2Key2":"b"}]
    ,"Level1Key2":123}');
    ajsonobj.path('[1][2]').print;
    ajsonobj.path('[1][2][1]').print;
    ajsonobj.path('["Level1Key1"][1]["Level2Key1"]').print;

    anotherjsonobj := pljson(ajsonobj.path('[1][1]'));
    anotherjsonobj.print;
    
    anotherjsonobj.put('Level2Key3', TRUE);
    ajsonobj.path_put('[1][1]', anotherjsonobj);
    ajsonobj.print;

    ajsonobj.path_put('[1][2]["Level2Key2"]', FALSE);
    ajsonobj.print;

    ajsonobj.path_remove('["Level1Key1"][2]');
    ajsonobj.print;

END;



DECLARE
    ajsonobj pljson;
    avarchar2 VARCHAR2(200);
    anumber NUMBER;
BEGIN
    ajsonobj := pljson('{"key1":null,"key2":""}');
    ajsonobj.put('key3', '');
    avarchar2 := NULL;
    ajsonobj.put('key4', avarchar2);
    anumber := NULL;
    ajsonobj.put('key5', anumber);
    ajsonobj.print;
END;



--JSON引用示例 --值引用
DECLARE
    --json对象
    ajsonobj pljson;
    --json数组
    ajsonarray pljson_list;
BEGIN
    ajsonobj   := pljson('{"key1":"1","key2":"2"}');
    ajsonarray := pljson_list();
    ajsonarray.append(ajsonobj.to_json_value, 1);
    ajsonarray.print;
    ajsonobj.put('key1', 'a');
    ajsonarray.print;
    ajsonobj.print;
END;



declare
  obj pljson;
  list pljson_list;
begin
  DBMS_OUTPUT.ENABLE(NULL);
  obj := pljson('
    {
      "a": null,
      "b": 12.243,
      "c": 2e-3,
      "d": [true, false, "abdc", [1,2,3]],
      "e": [3, {"e2":3}],
      "f": {
        "f2":true
      }
    }');
  obj.print;
  -- equivalent to print
  dbms_output.put_line(obj.to_char);

  -- print compact way
  obj.print(false);
  -- equivalent to print compact way
  dbms_output.put_line(obj.to_char(false));

  -- add to json object
  obj.put('g', 'a little string');
  -- remove from json object
  obj.remove('g');

  -- count of direct members in json object
  dbms_output.put_line(obj.count);

  -- test if an element exists
  if not obj.exist('json is good') then
    obj.put('json is good', 'Yes!');
    if obj.exist('json is good') then
      obj.print;
      dbms_output.put_line(':-)');
    end if;
  end if;

  -- you can build lists (arrays) too
  -- however notice that we have to use the 'to_json_value' function on json objects
  list := pljson_list(); --fresh list;
  list.append(pljson('{"lazy construction": true}').to_json_value);
  list.append(pljson_list('[1,2,3,4,5]'));
  list.print;
    -- empty list and nested lists are supported
  list := pljson_list('[1,2,3,[3, []]]');
  list.print;
  -- count of direct members in json list
  dbms_output.put_line(list.count);

  -- you can also put json object or json lists as values
  obj.put('nested json', pljson('{"lazy construction": true}'));
  obj.put('an array', pljson_list('[1,2,3,4,5]'));
  obj.print;

  -- support for dates
  obj.put('a date', pljson_ext.to_json_value(to_date('2017-10-21', 'YYYY-MM-DD')));
  -- and convert it back
  dbms_output.put_line(pljson_ext.to_date(obj.get('a date')));

  obj := pljson(
    '{
      "a" : true,
      "b" : [1,2,"3"],
      "c" : {
        "d" : [["array of array"], null, { "e": 7913 }]
      }
    }');

  -- get elements using a json path expression
  -- pljson supports a simple dot path expression and '[n]' for arrays
  -- it never raises an exception (null is returned instead)
  -- arrays are 1-indexed
  -- the empty string as path returns the entire json object
  -- can 'get_string', 'get_number', etc.
  dbms_output.put_line(pljson_ext.get_number(obj, 'c.d[3].e'));

  -- all pljson_... objects are copies
  -- so modification in place is difficult
  -- but put with path can do it
  pljson_ext.put(obj, 'c.d[3].e', 123);
  obj.print;

  -- if you provide an invalid path then an error is raised
  -- you can, however, specify a path that doesn't exists but should be created
  -- arrays are 1-indexed.
  -- gaps will be filled with json null(s)
  

  
  obj := pljson();
  pljson_ext.put(obj, 'a[2].data.value[1][2].myarray', pljson_list('[1,2,3]'));
  obj.print;
  -- fill the holes
  pljson_ext.put(obj, 'a[1]', 'filler1');
  pljson_ext.put(obj, 'a[2].data.value[1][1]', 'filler2');
  obj.print;
  -- replace larger structures:
  pljson_ext.put(obj, 'a[2].data', 7913);
  obj.print;

  obj := pljson(
    '{
      "a" : true,
      "b" : [1,2,"3"],
      "c" : {
        "d" : [["array of array"], null, { "e": 7913 }]
      }
    }');
  obj.print;

  -- remove element
  pljson_ext.remove(obj, 'c.d[3].e');
  obj.print;
  -- remove array of array
  pljson_ext.remove(obj, 'c.d[1]');
  obj.print;
  -- remove null element
  pljson_ext.remove(obj, 'c.d[1]');
  obj.print;

  -- you can ignore check for duplicate keys
  obj := pljson();
  -- enables fast construction without checks for duplicate keys
  obj.check_duplicate(false);
  for i in 1 .. 10 loop
    obj.put('a'||i, i);
  end loop;
  obj.put('a'||5, 'tada');
  obj.print;
  obj.check_duplicate(true);
  -- fix possible duplicates but does not preserve order
  obj.remove_duplicates();
  obj.print;

  -- create json objects and lists from sql statements
  list := pljson_dyn.executeList('select * from EMP');
  list.print;
  obj := pljson_dyn.executeObject('select * from tab');
  obj.print;
end;
/

```


