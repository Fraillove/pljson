/*
This software has been released under the MIT license:

  Copyright (c) 2009 Jonas Krogsboell

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.
*/
/*
  Using the JSON_EXT package
*/

set serveroutput on format wrapped;
DECLARE
    obj      pljson := pljson();
    testdate DATE := DATE '2018-12-24'; --Xmas
    PROCEDURE p(v VARCHAR2) AS
    BEGIN
        dbms_output.put_line(NULL);
        dbms_output.put_line(v);
    END;
BEGIN
    obj.put('My favorite date', json_ext.to_json_value(testdate));
    obj.print;
    IF (json_ext.is_date(obj.get('My favorite date'))) THEN
        p('We can also test the value');
    END IF;
    p('And convert it back');
    dbms_output.put_line(json_ext.to_date2(obj.get('My favorite date')));
END;
/
