------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                            Copyright (C) 2003                            --
--                                ACT-Europe                                --
--                                                                          --
--  Authors: Dmitriy Anisimkov - Pascal Obry                                --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.          --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

--  $Id$

with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Exceptions;
with Ada.Strings.Unbounded;
with Ada.Strings.Fixed;
with Ada.Text_IO;

with GNAT.Calendar.Time_IO;

with AWS;
with AWS.OS_Lib;
with SOAP.Utils;
with SOAP.WSDL.Parameters;

package body SOAP.Generator is

   use Ada;
   use Ada.Exceptions;
   use Ada.Strings.Unbounded;

   function Format_Name (O : in Object; Name : in String) return String;
   --  Returns Name formated with the Ada style if O.Ada_Style is true and
   --  Name unchanged otherwise.

   function Time_Stamp return String;
   --  Returns a time stamp Ada comment line

   function Version_String return String;
   --  Returns a version string Ada comment line

   procedure Put_File_Header (O : in Object; File : in Text_IO.File_Type);
   --  Add a standard file header into file.

   procedure Put_Types
     (O      : in Object;
      Proc   : in String;
      Input  : in WSDL.Parameters.P_Set;
      Output : in WSDL.Parameters.P_Set);
   --  This must be called to create the data types for composite objects

   procedure Put_Header
     (File   : in Text_IO.File_Type;
      O      : in Object;
      Proc   : in String;
      Input  : in WSDL.Parameters.P_Set;
      Output : in WSDL.Parameters.P_Set);
   --  Output procedure header into File. The terminating ';' or 'is' is not
   --  outputed for this routine to be used to generate the spec and body.

   function SOAP_Constructor
     (P_Type : in WSDL.Parameter_Type)
      return Character;
   --  Return the SOAP types constructor for P_Type

   function Result_Type
     (O      : in Object;
      Proc   : in String;
      Output : in WSDL.Parameters.P_Set)
      return String;
   --  Returns the result type given the output parameters

   procedure Header_Box
     (O    : in Object;
      File : in Text_IO.File_Type;
      Name : in String);
   --  Generate header box

   Root     : Text_IO.File_Type; -- Parent packages
   Type_Ads : Text_IO.File_Type; -- Child with all type defintions
   Type_Adb : Text_IO.File_Type;
   Stub_Ads : Text_IO.File_Type; -- Child with client interface
   Stub_Adb : Text_IO.File_Type;
   Skel_Ads : Text_IO.File_Type; -- Child with server interface
   Skel_Adb : Text_IO.File_Type;

   --  Stub generator routines

   package Stub is

      procedure Start_Service
        (O             : in out Object;
         Name          : in     String;
         Documentation : in     String;
         Location      : in     String);

      procedure End_Service
        (O    : in out Object;
         Name : in     String);

      procedure New_Procedure
        (O          : in out Object;
         Proc       : in     String;
         SOAPAction : in     String;
         Input      : in     WSDL.Parameters.P_Set;
         Output     : in     WSDL.Parameters.P_Set;
         Fault      : in     WSDL.Parameters.P_Set);

   end Stub;

   --  Skeleton generator routines

   package Skel is

      procedure Start_Service
        (O             : in out Object;
         Name          : in     String;
         Documentation : in     String;
         Location      : in     String);

      procedure End_Service
        (O    : in out Object;
         Name : in     String);

      procedure New_Procedure
        (O          : in out Object;
         Proc       : in     String;
         SOAPAction : in     String;
         Input      : in     WSDL.Parameters.P_Set;
         Output     : in     WSDL.Parameters.P_Set;
         Fault      : in     WSDL.Parameters.P_Set);

   end Skel;

   --  Simple name set used to keep record of all generated types

   package Name_Set is

      procedure Add (Name : in String);
      --  Add new name into the set

      function Exists (Name : in String) return Boolean;
      --  Returns true if Name is in the set

   end Name_Set;

   ---------------
   -- Ada_Style --
   ---------------

   procedure Ada_Style (O : in out Object) is
   begin
      O.Ada_Style := True;
   end Ada_Style;

   -------------
   -- CVS_Tag --
   -------------

   procedure CVS_Tag (O : in out Object) is
   begin
      O.CVS_Tag := True;
   end CVS_Tag;

   -----------------
   -- End_Service --
   -----------------

   procedure End_Service
     (O    : in out Object;
      Name : in     String)
   is
      L_Name  : constant String := Format_Name (O, Name);
   begin
      --  Root

      Text_IO.New_Line (Root);
      Text_IO.Put_Line (Root, "end " & L_Name & ";");

      Text_IO.Close (Root);

      --  Types

      Text_IO.New_Line (Type_Ads);
      Text_IO.Put_Line (Type_Ads, "end " & L_Name & ".Types;");

      Text_IO.Close (Type_Ads);

      Text_IO.New_Line (Type_Adb);
      Text_IO.Put_Line (Type_Adb, "end " & L_Name & ".Types;");

      Text_IO.Close (Type_Adb);

      --  Stub

      if O.Gen_Stub then
         Stub.End_Service (O, Name);
         Text_IO.Close (Stub_Ads);
         Text_IO.Close (Stub_Adb);
      end if;

      --  Skeleton

      if O.Gen_Skel then
         Skel.End_Service (O, Name);
         Text_IO.Close (Skel_Ads);
         Text_IO.Close (Skel_Adb);
      end if;
   end End_Service;

   -----------------
   -- Format_Name --
   -----------------

   function Format_Name (O : in Object; Name : in String) return String is

      function Ada_Format (Name : in String) return String;
      --  Returns Name with the Ada style

      function Ada_Format (Name : in String) return String is
         Result : Unbounded_String;
      begin
         for K in Name'Range loop
            if K = Name'First then
               Append (Result, Characters.Handling.To_Upper (Name (K)));

            elsif Characters.Handling.Is_Upper (Name (K))
              and then K > Name'First
              and then Name (K - 1) /= '_'
              and then Name (K - 1) /= '.'
              and then K < Name'Last
              and then Name (K + 1) /= '_'
              and then Name (K + 1) /= '.'
            then
               Append (Result, "_" & Name (K));

            else
               Append (Result, Name (K));
            end if;
         end loop;

         return To_String (Result);
      end Ada_Format;

   begin
      if O.Ada_Style then
         return Ada_Format (Name);
      else
         return Name;
      end if;
   end Format_Name;

   ----------------
   -- Header_Box --
   ----------------

   procedure Header_Box
     (O    : in Object;
      File : in Text_IO.File_Type;
      Name : in String)
   is
      pragma Unreferenced (O);
   begin
      Text_IO.Put_Line
        (File, "   " & String'(1 .. 6 + Name'Length => '-'));
      Text_IO.Put_Line
        (File, "   -- " & Name & " --");
      Text_IO.Put_Line
        (File, "   " & String'(1 .. 6 + Name'Length => '-'));
   end Header_Box;

   --------------
   -- Name_Set --
   --------------

   package body Name_Set is separate;

   -------------------
   -- New_Procedure --
   -------------------

   procedure New_Procedure
     (O          : in out Object;
      Proc       : in     String;
      SOAPAction : in     String;
      Input      : in     WSDL.Parameters.P_Set;
      Output     : in     WSDL.Parameters.P_Set;
      Fault      : in     WSDL.Parameters.P_Set) is
   begin
      if not O.Quiet then
         Text_IO.Put ("   > " & Proc);
         Text_IO.Put_Line ("  " & SOAPAction);
      end if;

      Put_Types (O, Proc, Input, Output);

      if O.Gen_Stub then
         Stub.New_Procedure (O, Proc, SOAPAction, Input, Output, Fault);
      end if;

      if O.Gen_Skel then
         Skel.New_Procedure (O, Proc, SOAPAction, Input, Output, Fault);
      end if;
   end New_Procedure;

   -------------
   -- No_Skel --
   -------------

   procedure No_Skel (O : in out Object) is
   begin
      O.Gen_Skel := False;
   end No_Skel;

   -------------
   -- No_Stub --
   -------------

   procedure No_Stub (O : in out Object) is
   begin
      O.Gen_Stub := False;
   end No_Stub;

   ---------------
   -- Overwrite --
   ---------------

   procedure Overwrite (O : in out Object) is
   begin
      O.Force := True;
   end Overwrite;

   ---------------------
   -- Put_File_Header --
   ---------------------

   procedure Put_File_Header (O : in Object; File : in Text_IO.File_Type) is
   begin
      Text_IO.New_Line (File);
      Text_IO.Put_Line (File, "--  wsdl2aws SOAP Generator v" & Version);
      Text_IO.Put_Line (File, "--");
      Text_IO.Put_Line (File, Version_String);
      Text_IO.Put_Line (File, Time_Stamp);
      Text_IO.New_Line (File);

      if O.CVS_Tag then
         Text_IO.Put_Line (File, "--  $" & "Id$");
         Text_IO.New_Line (File);
      end if;
   end Put_File_Header;

   ----------------
   -- Put_Header --
   ----------------

   procedure Put_Header
     (File   : in Text_IO.File_Type;
      O      : in Object;
      Proc   : in String;
      Input  : in WSDL.Parameters.P_Set;
      Output : in WSDL.Parameters.P_Set)
   is
      use Ada.Strings.Fixed;
      use type SOAP.WSDL.Parameters.P_Set;
      use type SOAP.WSDL.Parameters.Kind;

      L_Proc  : constant String := Format_Name (O, Proc);
      Max_Len : Positive := 1;

      N       : WSDL.Parameters.P_Set;
   begin
      --  Compute maximum name length
      N := Input;

      while N /= null loop
         Max_Len := Positive'Max
           (Max_Len, Format_Name (O, To_String (N.Name))'Length);
         N := N.Next;
      end loop;

      --  Ouput header

      Text_IO.Put_Line (File, "function " & L_Proc);
      Text_IO.Put      (File, "      (");

      --  Output parameters

      N := Input;

      while N /= null loop
         declare
            Name : constant String
              := Format_Name (O, To_String (N.Name));
         begin
            Text_IO.Put (File, Name);
            Text_IO.Put (File, (Max_Len - Name'Length) * ' ');
         end;

         Text_IO.Put (File, " : in ");

         if N.Mode = WSDL.Parameters.K_Simple then
            Text_IO.Put (File, WSDL.To_Ada (N.P_Type));
         else
            Text_IO.Put
              (File, Format_Name (O, To_String (N.C_Name)) & "_Type");
         end if;

         if N.Next = null then
            Text_IO.Put_Line (File, ")");
         else
            Text_IO.Put_Line (File, ";");
            Text_IO.Put      (File, "       ");
         end if;

         N := N.Next;
      end loop;

      Text_IO.Put (File, "       return ");

      Text_IO.Put (File, Result_Type (O, Proc, Output));
   end Put_Header;

   ---------------
   -- Put_Types --
   ---------------

   procedure Put_Types
     (O      : in Object;
      Proc   : in String;
      Input  : in WSDL.Parameters.P_Set;
      Output : in WSDL.Parameters.P_Set)
   is
      use type WSDL.Parameters.Kind;
      use type WSDL.Parameters.P_Set;

      procedure Generate_Record
        (Name   : in String;
         P      : in WSDL.Parameters.P_Set;
         Output : in Boolean               := False);
      --  Output record definitions (type and routine conversion)

      function Type_Name (N : in WSDL.Parameters.P_Set) return String;
      --  Returns the name of the type for parameter on node N

      function Array_Type (Name : in String) return String;
      --  Returns the type of the array element given the array Name

      procedure Generate_Array (P : in WSDL.Parameters.P_Set);
      --  Generate array definitions (type and routine conversion)

      procedure Output_Types (P : in WSDL.Parameters.P_Set);
      --  Output types convertion routines

      function Get_Routine (P : in WSDL.Parameters.P_Set) return String;
      --  Returns the Get routine for the given type

      function Set_Routine (P : in WSDL.Parameters.P_Set) return String;
      --  Returns the constructor routine for the given type

      function Set_Type (Name : in String) return String;
      --  Returns the SOAP type for Name

      ----------------
      -- Array_Type --
      ----------------

      function Array_Type (Name : in String) return String is
         K : Natural := Strings.Fixed.Index (Name, "_");
      begin
         if K = 0 then
            K := Name'Last;
         else
            K := K - 1;
         end if;

         --  First character is converted in lower case

         return Characters.Handling.To_Lower (Name (8)) & Name (9 .. K);
      end Array_Type;

      --------------------
      -- Generate_Array --
      --------------------

      procedure Generate_Array (P : in WSDL.Parameters.P_Set) is

         function To_Ada_Type (Name : in String) return String;
         --  Returns the Ada corresponding type

         -----------------
         -- To_Ada_Type --
         -----------------

         function To_Ada_Type (Name : in String) return String is
         begin
            if Name = "Float" then
               return "Long_Float";

            elsif Name = "String" then
               return "Unbounded_String";

            elsif WSDL.Is_Standard (Name) then
               return Name;

            else
               return Name & "_Type";
            end if;
         end To_Ada_Type;

         Name   : constant String
           := Format_Name (O, To_String (P.C_Name));

         T_Name : constant String
           := Slice (P.C_Name, 8, Length (P.C_Name));

      begin
         Text_IO.New_Line (Type_Ads);
         Text_IO.Put_Line
           (Type_Ads, "   " & String'(1 .. 12 + Name'Length => '-'));
         Text_IO.Put_Line
           (Type_Ads, "   -- Array " & Name & " --");
         Text_IO.Put_Line
           (Type_Ads, "   " & String'(1 .. 12 + Name'Length => '-'));

         Text_IO.New_Line (Type_Ads);

         Text_IO.Put_Line
           (Type_Ads, "   type " & Name
              & " is array (Positive range <>) of "
              & To_Ada_Type (T_Name) & ";");
         Text_IO.Put_Line
           (Type_Ads, "   type "
              & Name & "_Access" & " is access all " & Name & ';');

         Text_IO.New_Line (Type_Ads);
         Text_IO.Put_Line
           (Type_Ads, "   function To_" & Name
              & " is new SOAP.Utils.To_T_Array");
         Text_IO.Put_Line
           (Type_Ads, "     (" & To_Ada_Type (T_Name) & ", " & Name & ",");
         Text_IO.Put_Line
           (Type_Ads,
            "      " & Name & "_Access, " & Get_Routine (P) & ");");

         Text_IO.New_Line (Type_Ads);
         Text_IO.Put_Line
           (Type_Ads, "   function To_Object_Set"
              & " is new SOAP.Utils.To_Object_Set");
         Text_IO.Put_Line
           (Type_Ads, "     (" & To_Ada_Type (T_Name) & ", " & Name & ",");
         Text_IO.Put_Line
           (Type_Ads,
            "      " & Set_Type (T_Name) & ", " & Set_Routine (P) & ");");
      end Generate_Array;

      ---------------------
      -- Generate_Record --
      ---------------------

      procedure Generate_Record
        (Name   : in String;
         P      : in WSDL.Parameters.P_Set;
         Output : in Boolean               := False)
      is
         function V_Routine (Name : in String) return String;
         --  Returns the Ada corresponding type

         F_Name : constant String := Format_Name (O, Name);

         ---------------
         -- V_Routine --
         ---------------

         function V_Routine (Name : in String) return String is
         begin
            if Name = "String" then
               return "SOAP.Utils.V";

            else
               return "SOAP.Types.V";
            end if;
         end V_Routine;

         R   : WSDL.Parameters.P_Set;
         N   : WSDL.Parameters.P_Set;

         Max : Positive;

      begin
         if Output then
            R := P;
         else
            R := P.P;
         end if;

         --  Generate record type

         Text_IO.New_Line (Type_Ads);
         Header_Box (O, Type_Ads, "Record " & F_Name);

         --  Compute max filed width

         N := R;

         Max := 1;

         while N /= null loop
            Max := Positive'Max
              (Max, Format_Name (O, To_String (N.Name))'Length);
            N := N.Next;
         end loop;

         --  Output field

         N := R;

         Text_IO.New_Line (Type_Ads);
         Text_IO.Put_Line
           (Type_Ads, "   type " & F_Name & " is record");

         while N /= null loop
            declare
               F_Name : constant String := Format_Name (O, To_String (N.Name));
            begin
               Text_IO.Put
                 (Type_Ads, "      "
                    &  F_Name
                    & String'(1 .. Max - F_Name'Length => ' ') & " : ");
            end;

            Text_IO.Put (Type_Ads, Format_Name (O, Type_Name (N)));

            Text_IO.Put_Line (Type_Ads, ";");

            N := N.Next;
         end loop;

         Text_IO.Put_Line
           (Type_Ads, "   end record;");

         --  Generate convertion spec

         Text_IO.New_Line (Type_Ads);
         Text_IO.Put_Line (Type_Ads, "   function To_" & F_Name);

         Text_IO.Put_Line (Type_Ads, "     (O : in SOAP.Types.Object'Class)");
         Text_IO.Put_Line (Type_Ads, "      return " & F_Name & ';');

         Text_IO.New_Line (Type_Ads);
         Text_IO.Put_Line (Type_Ads, "   function To_SOAP_Object");

         Text_IO.Put_Line (Type_Ads, "     (R    : in " & F_Name & ';');
         Text_IO.Put_Line (Type_Ads, "      Name : in String := ""item"")");
         Text_IO.Put_Line (Type_Ads, "      return SOAP.Types.SOAP_Record;");

         --  Generate convertion body

         Text_IO.New_Line (Type_Adb);
         Header_Box (O, Type_Adb, "Record " & F_Name);

         Text_IO.New_Line (Type_Adb);
         Text_IO.Put_Line (Type_Adb, "   function To_" & F_Name);

         Text_IO.Put_Line (Type_Adb, "     (O : in SOAP.Types.Object'Class)");
         Text_IO.Put_Line (Type_Adb, "      return " & F_Name);
         Text_IO.Put_Line (Type_Adb, "   is");
         Text_IO.Put_Line
           (Type_Adb,
            "      R : constant SOAP.Types.SOAP_Record "
              & ":= SOAP.Types.SOAP_Record (O);");

         N := R;

         while N /= null loop
            if N.Mode = WSDL.Parameters.K_Simple then
               declare
                  I_Type : constant String
                    := Set_Type (WSDL.To_Ada (N.P_Type));
               begin
                  Text_IO.Put_Line
                    (Type_Adb,
                     "      " & Format_Name (O, To_String (N.Name))
                       & " : constant " & I_Type);
                  Text_IO.Put_Line
                    (Type_Adb,
                     "         := " & I_Type & " (SOAP.Types.V (R, """
                       & To_String (N.Name) & """));");
               end;

            else
               if Utils.Is_Array (To_String (N.C_Name)) then
                  Text_IO.Put_Line
                    (Type_Adb,
                     "      " & Format_Name (O, To_String (N.Name))
                       & " : constant SOAP.Types.SOAP_Array");
                  Text_IO.Put_Line
                    (Type_Adb,
                     "         := SOAP.Types.SOAP_Array (SOAP.Types.V (R, """
                       & To_String (N.Name) & """));");
               else
                  Text_IO.Put_Line
                    (Type_Adb,
                     "      " & Format_Name (O, To_String (N.Name))
                       & " : constant SOAP.Types.SOAP_Record");
                  Text_IO.Put_Line
                    (Type_Adb,
                     "         := SOAP.Types.SOAP_Record (SOAP.Types.V (R, """
                       & To_String (N.Name) & """));");
               end if;
            end if;

            N := N.Next;
         end loop;

         Text_IO.Put_Line (Type_Adb, "   begin");
         Text_IO.Put      (Type_Adb, "      return (");

         N := R;

         while N /= null loop
            if N /= R then
               Text_IO.Put      (Type_Adb, "              ");
            end if;

            if N.Mode = WSDL.Parameters.K_Simple then
               Text_IO.Put
                 (Type_Adb, V_Routine (WSDL.To_Ada (N.P_Type))
                    & " (" & Format_Name (O, To_String (N.Name)) & ')');

            else
               if Utils.Is_Array (To_String (N.C_Name)) then
                  Text_IO.Put
                    (Type_Adb, "To_" & Format_Name (O, To_String (N.C_Name))
                       & " (SOAP.Types.V ("
                       & Format_Name (O, To_String (N.Name)) & "))");

               else
                  Text_IO.Put (Type_Adb, Get_Routine (N));

                  Text_IO.Put
                    (Type_Adb, "(SOAP.Types.V ("
                       & Format_Name (O, To_String (N.Name)) & "))");
               end if;
            end if;

            if N.Next = null then
               Text_IO.Put_Line (Type_Adb, ");");
            else
               Text_IO.Put_Line (Type_Adb, ",");
            end if;

            N := N.Next;
         end loop;

         Text_IO.Put_Line (Type_Adb, "   end To_" & F_Name & ';');

         Text_IO.New_Line (Type_Adb);
         Text_IO.Put_Line (Type_Adb, "   function To_SOAP_Object");

         Text_IO.Put_Line (Type_Adb, "     (R : in " & F_Name & ';');
         Text_IO.Put_Line (Type_Adb, "      Name : in String := ""item"")");
         Text_IO.Put_Line (Type_Adb, "      return SOAP.Types.SOAP_Record");
         Text_IO.Put_Line (Type_Adb, "   is");
         Text_IO.Put_Line (Type_Adb, "      Result : SOAP.Types.SOAP_Record;");
         Text_IO.Put_Line (Type_Adb, "   begin");

         N := R;

         Text_IO.Put_Line (Type_Adb, "      Result := SOAP.Types.R");

         while N /= null loop

            if N = R then
               Text_IO.Put      (Type_Adb, "        ((+");
            else
               Text_IO.Put      (Type_Adb, "          +");
            end if;

            if N.Mode = WSDL.Parameters.K_Simple then
               Text_IO.Put (Type_Adb, Set_Routine (N));

               Text_IO.Put
                 (Type_Adb,
                  " (R." & Format_Name (O, To_String (N.Name))
                    & ", """ & To_String (N.Name) & """)");
            else
               if Utils.Is_Array (To_String (N.C_Name)) then
                  Text_IO.Put
                    (Type_Adb,
                     "SOAP.Types.A (To_Object_Set (R."
                       & Format_Name (O, To_String (N.Name)) & ".all), """
                       & To_String (N.Name) & """)");
               else
                  Text_IO.Put (Type_Adb, Set_Routine (N));

                  Text_IO.Put
                    (Type_Adb,
                     " (R." & Format_Name (O, To_String (N.Name)) & " )");
               end if;
            end if;

            if N.Next = null then
               Text_IO.Put_Line (Type_Adb, "),");
            else
               Text_IO.Put_Line (Type_Adb, ",");
            end if;

            N := N.Next;
         end loop;

         Text_IO.Put_Line
           (Type_Adb,
            "         """ & To_String (P.C_Name) & """);");

         Text_IO.Put_Line (Type_Adb, "      return Result;");
         Text_IO.Put_Line (Type_Adb, "   end To_SOAP_Object;");
      end Generate_Record;

      -----------------
      -- Get_Routine --
      -----------------

      function Get_Routine (P : in WSDL.Parameters.P_Set) return String is

         function Get_Routine (Name : in String) return String;

         -----------------
         -- Get_Routine --
         -----------------

         function Get_Routine (Name : in String) return String is
         begin
            if Name = "string" then
               return "SOAP.Utils.Get";
            else
               return "SOAP.Types.Get";
            end if;
         end Get_Routine;

         Name : constant String := Type_Name (P);

      begin
         if P.Mode = WSDL.Parameters.K_Simple then
            return Get_Routine (Name);

         elsif Utils.Is_Array (To_String (P.C_Name)) then
            declare
               T_Name : constant String := Array_Type (Name);
            begin
               if WSDL.Is_Standard (T_Name) then
                  return Get_Routine (T_Name);
               else
                  return "To_" & T_Name & "_Type";
               end if;
            end;

         else
            return "To_" & Name & "_Type";
         end if;
      end Get_Routine;

      ------------------
      -- Output_Types --
      ------------------

      procedure Output_Types (P : in WSDL.Parameters.P_Set) is
         N : WSDL.Parameters.P_Set := P;
      begin
         while N /= null loop
            if N.Mode = WSDL.Parameters.K_Composite then
               Output_Types (N.P);

               declare
                  Name : constant String := To_String (N.C_Name);
               begin
                  if not Name_Set.Exists (Name) then

                     Name_Set.Add (Name);

                     if Utils.Is_Array (Name) then
                        Generate_Array (N);

                     else
                        Generate_Record (Name & "_Type", N);
                     end if;
                  end if;
               end;
            end if;

            N := N.Next;
         end loop;
      end Output_Types;

      -----------------
      -- Set_Routine --
      -----------------

      function Set_Routine (P : in WSDL.Parameters.P_Set) return String is

         function Set_Routine (Name : in String) return String;
         --  Returns the routine use to build object with type Name

         -----------------
         -- Set_Routine --
         -----------------

         function Set_Routine (Name : in String) return String is
         begin
            if Name = "String" or else Name = "string" then
               return "SOAP.Types.S";

            elsif Name = "Unbounded_String" then
               return "SOAP.Utils.US";

            elsif Name = "Integer" or else Name = "integer" then
               return "SOAP.Types.I";

            elsif Name = "Float" or else Name = "float" then
               return "SOAP.Types.F";

            elsif Name = "Long_Float" then
               return "SOAP.Types.F";

            elsif Name = "Boolean" or else Name = "boolean" then
               return "SOAP.Types.B";

            elsif Name = "Ada.Calendar.Time" then
               return "SOAP.Types.T";

            else
               Raise_Exception
                 (Generator_Error'Identity,
                  "(Set_Routine): type " & Name & " not supported.");
            end if;
         end Set_Routine;

         Name : constant String := Type_Name (P);

      begin
         if P.Mode = WSDL.Parameters.K_Simple then
            return Set_Routine (Name);

         elsif  Utils.Is_Array (To_String (P.C_Name)) then
            declare
               T_Name : constant String := Array_Type (Name);
            begin
               if WSDL.Is_Standard (T_Name) then
                  return Set_Routine (T_Name);
               else
                  return "To_SOAP_Object";
               end if;
            end;

         else
            return "To_SOAP_Object";
         end if;
      end Set_Routine;

      --------------
      -- Set_Type --
      --------------

      function Set_Type (Name : in String) return String is
      begin
         if Name = "String" then
            return "SOAP.Types.XSD_String";

         elsif Name = "Integer" then
            return "SOAP.Types.XSD_Integer";

         elsif Name = "Float" then
            return "SOAP.Types.XSD_Float";

         elsif Name = "Long_Float" then
            return "SOAP.Types.XSD_Float";

         elsif Name = "Boolean" then
            return "SOAP.Types.XSD_Boolean";

         elsif Name = "Ada.Calendar.Time" then
            return "SOAP.Types.XSD_Time_Instant";

         elsif Utils.Is_Array (Name) then
            return "SOAP.Types.SOAP_Array";

         else
            return "SOAP.Types.SOAP_Record";
         end if;
      end Set_Type;

      ---------------
      -- Type_Name --
      ---------------

      function Type_Name (N : in WSDL.Parameters.P_Set) return String is
         use type WSDL.Parameter_Type;
      begin
         if N.Mode = WSDL.Parameters.K_Simple then
            if N.P_Type = WSDL.P_String then
               --  Inside a record we must use Unbounded_String
               return "Unbounded_String";
            else
               return WSDL.To_Ada (N.P_Type);
            end if;

         else
            if Utils.Is_Array (To_String (N.C_Name)) then
               return To_String (N.C_Name) & "_Access";
            else
               return To_String (N.C_Name) & "_Record";
            end if;
         end if;
      end Type_Name;

      L_Proc : constant String := Format_Name (O, Proc);

   begin
      Output_Types (Input);

      Output_Types (Output);

      --  Output mode and more than one parameter

      if Output.Next = null then
         --  A single declaration, if it is a composite type create a subtype

         if Output.Mode = WSDL.Parameters.K_Composite then
            Text_IO.New_Line (Type_Ads);
            Text_IO.Put_Line
              (Type_Ads,
               "   subtype " & L_Proc & "_Result is "
                 & To_String (Output.C_Name) & "_Type;");
         end if;

      else
         Generate_Record (L_Proc & "_Result", Output, Output => True);
      end if;
   end Put_Types;

   -----------
   -- Quiet --
   -----------

   procedure Quiet (O : in out Object) is
   begin
      O.Quiet := True;
   end Quiet;

   -----------------
   -- Result_Type --
   -----------------

   function Result_Type
     (O      : in Object;
      Proc   : in String;
      Output : in WSDL.Parameters.P_Set)
      return String
   is
      use type WSDL.Parameters.Kind;

      L_Proc : constant String := Format_Name (O, Proc);
   begin
      if WSDL.Parameters.Length (Output) = 1
        and then Output.Mode = WSDL.Parameters.K_Simple
      then
         return WSDL.To_Ada (Output.P_Type);
      else
         return L_Proc & "_Result";
      end if;
   end Result_Type;

   ----------
   -- Skel --
   ----------

   package body Skel is separate;

   ----------------------
   -- SOAP_Constructor --
   ----------------------

   function SOAP_Constructor
     (P_Type : in WSDL.Parameter_Type)
      return Character is
   begin
      case P_Type is
         when WSDL.P_Integer => return 'I';
         when WSDL.P_Float   => return 'F';
         when WSDL.P_String  => return 'S';
         when WSDL.P_Boolean => return 'B';
         when WSDL.P_Time    => return 'T';
      end case;
   end SOAP_Constructor;

   -------------------
   -- Start_Service --
   -------------------

   procedure Start_Service
     (O             : in out Object;
      Name          : in     String;
      Documentation : in     String;
      Location      : in     String)
   is
      procedure Create (File : in out Text_IO.File_Type; Filename : in String);
      --  Create Filename, raise execption Generator_Error if the file already
      --  exists and overwrite mode not activated.

      ------------
      -- Create --
      ------------

      procedure Create
        (File     : in out Text_IO.File_Type;
         Filename : in     String) is
      begin
         if AWS.OS_Lib.Is_Regular_File (Filename) and then not O.Force then
            Raise_Exception
              (Generator_Error'Identity,
               "File " & Filename & " exists, activate overwrite mode.");
         else
            Text_IO.Create (File, Text_IO.Out_File, Filename);
         end if;
      end Create;

      L_Name  : constant String := Format_Name (O, Name);
      LL_Name : constant String := Characters.Handling.To_Lower (L_Name);

   begin
      if not O.Quiet then
         Text_IO.New_Line;
         Text_IO.Put_Line ("Service " & Name);
         Text_IO.Put_Line ("   " & Documentation);
      end if;

      Create (Root, LL_Name & ".ads");

      Create (Type_Ads, LL_Name & "-types.ads");
      Create (Type_Adb, LL_Name & "-types.adb");

      if O.Gen_Stub then
         Create (Stub_Ads, LL_Name & "-client.ads");
         Create (Stub_Adb, LL_Name & "-client.adb");
      end if;

      if O.Gen_Skel then
         Create (Skel_Ads, LL_Name & "-server.ads");
         Create (Skel_Adb, LL_Name & "-server.adb");
      end if;

      --  Types

      Put_File_Header (O, Type_Ads);

      Text_IO.Put_Line (Type_Ads, "with Ada.Calendar;");
      Text_IO.Put_Line (Type_Ads, "with Ada.Strings.Unbounded;");
      Text_IO.New_Line (Type_Ads);
      Text_IO.Put_Line (Type_Ads, "with SOAP.Types;");
      Text_IO.Put_Line (Type_Ads, "with SOAP.Utils;");
      Text_IO.New_Line (Type_Ads);

      Text_IO.Put_Line (Type_Ads, "package " & L_Name & ".Types is");
      Text_IO.New_Line (Type_Ads);
      Text_IO.Put_Line (Type_Ads, "   pragma Warnings (Off, Ada.Calendar);");
      Text_IO.Put_Line
        (Type_Ads, "   pragma Warnings (Off, Ada.Strings.Unbounded);");
      Text_IO.Put_Line (Type_Ads, "   pragma Warnings (Off, SOAP.Types);");
      Text_IO.Put_Line (Type_Ads, "   pragma Warnings (Off, SOAP.Utils);");
      Text_IO.New_Line (Type_Ads);
      Text_IO.Put_Line (Type_Ads, "   pragma Elaborate_Body;");
      Text_IO.New_Line (Type_Ads);
      Text_IO.Put_Line (Type_Ads, "   use Ada.Strings.Unbounded;");

      Put_File_Header (O, Type_Adb);

      Text_IO.Put_Line (Type_Adb, "package body " & L_Name & ".Types is");
      Text_IO.New_Line (Type_Adb);
      Text_IO.Put_Line (Type_Adb, "   use SOAP.Types;");

      --  Root

      Put_File_Header (O, Root);

      Text_IO.Put_Line (Root, "--  " & Documentation);
      Text_IO.Put_Line (Root, "--  Service at : " & Location);
      Text_IO.New_Line (Root);
      Text_IO.Put_Line (Root, "package " & L_Name & " is");

      if O.WSDL_File /= Null_Unbounded_String then
         Text_IO.New_Line (Root);
         Text_IO.Put_Line (Root, "   pragma Style_Checks (Off);");

         declare
            File   : Text_IO.File_Type;
            Buffer : String (1 .. 1_024);
            Last   : Natural;
         begin
            Text_IO.Open (File, Text_IO.In_File, To_String (O.WSDL_File));

            while not Text_IO.End_Of_File (File) loop
               Text_IO.Get_Line (File, Buffer, Last);
               Text_IO.Put_Line (Root, "--  " & Buffer (1 .. Last));
            end loop;

            Text_IO.Close (File);
         end;

         Text_IO.Put_Line (Root, "   pragma Style_Checks (On);");
         Text_IO.New_Line (Root);
      end if;

      if O.Gen_Stub then
         Put_File_Header (O, Stub_Ads);
         Put_File_Header (O, Stub_Adb);
         Stub.Start_Service (O, Name, Documentation, Location);
      end if;

      if O.Gen_Skel then
         Put_File_Header (O, Skel_Ads);
         Put_File_Header (O, Skel_Adb);
         Skel.Start_Service (O, Name, Documentation, Location);
      end if;
   end Start_Service;

   ----------
   -- Stub --
   ----------

   package body Stub is separate;

   ----------------
   -- Time_Stamp --
   ----------------

   function Time_Stamp return String is
   begin
      return "--  This file was generated on "
        & GNAT.Calendar.Time_IO.Image
            (Ada.Calendar.Clock, "%A %d %B %Y at %T");
   end Time_Stamp;

   --------------------
   -- Version_String --
   --------------------

   function Version_String return String is
   begin
      return "--  AWS " & AWS.Version
        & " - SOAP " & SOAP.Version;
   end Version_String;

   ---------------
   -- WSDL_File --
   ---------------

   procedure WSDL_File (O : in out Object; Filename : in String) is
   begin
      O.WSDL_File := To_Unbounded_String (Filename);
   end WSDL_File;

end SOAP.Generator;
