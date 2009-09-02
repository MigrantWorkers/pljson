create or replace package json_printer as
  /*
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
  indent_string varchar2(10) := '  '; --chr(9); for tab

  function pretty_print(obj json, spaces boolean default true) return varchar2;
  function pretty_print_list(obj json_list, spaces boolean default true) return varchar2;
end json_printer;
/

CREATE OR REPLACE PACKAGE BODY "JSON_PRINTER" as
  /*
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
  function get_schema return varchar2 as
  begin
    return sys_context('userenv', 'current_schema');
  end;  

  function tab(indent number, spaces boolean) return varchar2 as
    i varchar(200) := '';
  begin
    if(not spaces) then return ''; end if;
    for x in 1 .. indent loop i := i || indent_string; end loop;
    return i;
  end;
  
  procedure ppObj(obj json, indent number, buf in out nocopy varchar2, spaces boolean);

  function getCommaSep(spaces boolean) return varchar2 as
  begin
    if(spaces) then return ', '; else return ','; end if;
  end;

  procedure ppEA(input json_list, indent number, buf in out varchar2, spaces boolean) as
    elem json_element; 
    x number; t_num number; t_str varchar2(4000); bool json_bool; obj json; jlist json_list;
    arr json_element_array := input.list_data;
  begin
    for y in 1 .. arr.count loop
      elem := arr(y);
      if(elem is not null) then
      case elem.element_data.gettypename
        when 'SYS.NUMBER' then 
          x := elem.element_data.getnumber(t_num);
          buf := buf || to_char(t_num, 'TM', 'NLS_NUMERIC_CHARACTERS=''.,''');
        when 'SYS.VARCHAR2' then 
          x := elem.element_data.getvarchar2(t_str);
          buf := buf || '"' || t_str || '"';
        when get_schema || '.JSON_BOOL' then
          x := elem.element_data.getobject(bool);
          buf := buf || bool.to_char;
        when get_schema || '.JSON_NULL' then
          buf := buf || 'null';
        when get_schema || '.JSON_LIST' then
          buf := buf || '[';
          x := elem.element_data.getobject(jlist);
          ppEA(jlist, indent, buf, spaces);
          buf := buf || ']';
        when get_schema || '.JSON' then
          x := elem.element_data.getobject(obj);
          ppObj(obj, indent, buf, spaces);
        else buf := buf || elem.element_data.gettypename;
      end case;
      end if;
      if(y != arr.count) then buf := buf || getCommaSep(spaces); end if;
    end loop;
  end ppEA;

  function getMemName(mem json_member, spaces boolean) return varchar2 as
  begin
    if(spaces) then
      return '"' || mem.member_name || '" : ';
    else 
      return '"' || mem.member_name || '":';
    end if;
  end;

  procedure ppMem(mem json_member, indent number, buf in out nocopy varchar2, spaces boolean) as
    x number; t_num number; t_str varchar2(4000); bool json_bool; obj json; jlist json_list;
  begin
    buf := buf || tab(indent, spaces) || getMemName(mem, spaces);
    case mem.member_data.gettypename
      when 'SYS.NUMBER' then 
        x := mem.member_data.getnumber(t_num);
        buf := buf || to_char(t_num, 'TM', 'NLS_NUMERIC_CHARACTERS=''.,''');
      when 'SYS.VARCHAR2' then 
        x := mem.member_data.getvarchar2(t_str);
        buf := buf || '"' || t_str || '"';
      when get_schema || '.JSON_BOOL' then
        x := mem.member_data.getobject(bool);
        buf := buf || bool.to_char;
      when get_schema || '.JSON_NULL' then
        buf := buf || 'null';
      when get_schema || '.JSON_LIST' then
        buf := buf || '[';
        x := mem.member_data.getobject(jlist);
        ppEA(jlist, indent, buf, spaces);
        buf := buf || ']';
      when get_schema || '.JSON' then
        x := mem.member_data.getobject(obj);
        ppObj(obj, indent, buf, spaces);
      else buf := buf || mem.member_data.gettypename;
    end case;
  end ppMem;
  
  function newline(spaces boolean) return varchar2 as
  begin
    if(spaces) then return chr(13); else return ''; end if;
  end;

  procedure ppObj(obj json, indent number, buf in out nocopy varchar2, spaces boolean) as
  begin
    buf := buf || '{' || newline(spaces);
    for m in 1 .. obj.json_data.count loop
      ppMem(obj.json_data(m), indent+1, buf, spaces);
      if(m != obj.json_data.count) then buf := buf || ',' || newline(spaces);
      else buf := buf || newline(spaces); end if;
    end loop;
    buf := buf || tab(indent, spaces) || '}'; -- || chr(13);
  end ppObj;
  
  function pretty_print(obj json, spaces boolean default true) return varchar2 as
    buf varchar2(32676) := '';
  begin
    ppObj(obj, 0, buf, spaces);
    return buf;
  end pretty_print;

  function pretty_print_list(obj json_list, spaces boolean default true) return varchar2 as
    buf varchar2(32676) := '[';
  begin
    ppEA(obj, 0, buf, spaces);
    buf := buf || ']';
    return buf;
  end;

end json_printer;/

