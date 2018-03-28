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
  Working with errors/exceptions
  The parser follows the json specification described @ www.json.org  
*/

DECLARE
    scanner_exception EXCEPTION;
    PRAGMA EXCEPTION_INIT(scanner_exception, -20100);
    parser_exception EXCEPTION;
    PRAGMA EXCEPTION_INIT(parser_exception, -20101);

    obj pljson;
BEGIN
    obj := pljson('this is not valid json');
    --displays ORA-20100: JSON Scanner exception @ line: 1 column: 1 - Expected: 'true'
    --thats because the closest match was a boolean
    obj.print;
EXCEPTION
    WHEN scanner_exception THEN
        dbms_output.put_line(SQLERRM);
    WHEN parser_exception THEN
        dbms_output.put_line(SQLERRM);
END;
