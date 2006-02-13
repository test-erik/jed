% -*- SLang -*-
%
% run compiler in a subshell and/or parse error messages
%
% Changes made by Alexander Demenshin <aldem@barnet.kharkov.ua>
% Column support by Lutz Donnerhacke <lutz@iks-jena.de>.
%
% Public functions:
%   compile_parse_errors		parse next error
%   compile_previous_error		parse previous error
%   compile_parse_buf    		parse current buffer as error messages
%   compile			        run program and parse it output
%   compile_select_compiler             set compiler for parsing error messages
%   compile_add_compiler                add a compiler to database
%
% Public variables:
%   Compile_Default_Compiler
%
% The file also contains a database for various compilers.
%---------------------------------------------------------------------------

% These variables are public because they are used by acompile.sl
variable Compile_Output_Buffer = "*shell-output*";
if (is_defined ("get_process_input"))
{
   Compile_Output_Buffer = "*compile*";
}
variable Compile_Line_Mark = 0;

private variable Compile_Src_Dir = Null_String;
private variable Error_Regexp;

%
%  These variables are used when parsing GNU's Make output (directory changes).
%  I don't know what kind of output generated by other Make, so substitute
%  it if needed. <aldem>
%
#ifdef UNIX
private variable Compile_Dir_Enter = "^g?make\\[\\d+\\]: Entering directory `\\(.+\\)'";
private variable Compile_Dir_Leave = "^g?make\\[\\d+\\]: Leaving directory `\\(.+\\)'";

private define compile_parse_make_chdir ()
{
   variable beg_mark, end_mark;
   variable end_line;

   push_spot ();
   EXIT_BLOCK
     {
	pop_spot ();
     }

   beg_mark = create_user_mark ();
   end_mark = create_user_mark ();

   forever
     {
	goto_user_mark (end_mark);

	end_line = 0;

	if (re_bsearch (Compile_Dir_Leave))
	  {
	     if (up_1 ())
	       end_line = what_line ();

	     move_user_mark (end_mark);
	  }

	goto_user_mark (beg_mark);

	!if (up_1 ()) return Null_String;

	if (re_bsearch (Compile_Dir_Enter))
	  {
	     if (not(end_line)
		 or (what_line () > end_line))
	       break;
	     move_user_mark (beg_mark);
	  }
	else return Null_String;
     }
   regexp_nth_match (1);
}

#endif

private define compile_find_file (file, line, col)
{
#ifdef UNIX
   variable dir;

   dir = compile_parse_make_chdir ();
   if (strlen (dir) and (file[0] != '/'))
     file = dircat (dir, file);
#endif

   if (1 != file_status (file))
     {
	file = Compile_Src_Dir + file;
	while (1 != file_status (file))
	  {
	     file = read_file_from_mini ("Find this file's errors:");
	  }
     }

   Compile_Src_Dir = path_dirname (file);

   () = find_file (file);
   widen_buffer ();
   goto_line (line);
   if (col > 0)
     goto_column_best_try (col);
   else
     bol_skip_white ();
}

private define compile_parse_errors_dir (next_error_fun, next_line_fun)
{
   variable cbuf, obuf = Compile_Output_Buffer;
   variable line, file, col;

   Compile_Line_Mark = 0;

   !if (bufferp(obuf))
     {
	flush ("Did you compile?");
	return;
     }

   if (MINIBUFFER_ACTIVE) return;

   cbuf = pop2buf_whatbuf (obuf);

   if (@next_error_fun (&file, &line, &col))
     {
	!if (strlen (line)) return;
	!if (strlen (col)) col = "0";

	bol();
	Compile_Line_Mark = create_line_mark (3);

	@next_line_fun ();

        line = strtrim_beg (line, " \t0");
        col = strtrim_beg (col, " \t0");
	compile_find_file (file, integer (line), integer (col));
	cbuf = whatbuf ();
	sw2buf (obuf);
     }
  
   pop2buf (cbuf);
}

private define compile_find_next_error_fun (filep, linep, colp)
{
   eol ();
   if (eobp ())
     {
	message ("No more errors!");
	return 0;
     }

   if (typeof (Error_Regexp) == Ref_Type)
     return @Error_Regexp (1, filep, linep, colp);

   bol ();
   !if (re_fsearch (Error_Regexp))
     {
	eob ();
	return 0;
     }

   @filep = regexp_nth_match (1);	% file name
   @linep = regexp_nth_match (2);	% line number (string)
   @colp  = regexp_nth_match (3);	% column number (string)

   1;
}

private define compile_find_prev_error_fun (filep, linep, colp)
{
   bol ();
   if (bobp ())
     {
	message ("No more errors!");
	0;
     }

   if (typeof (Error_Regexp) == Ref_Type)
     return @Error_Regexp (-1, filep, linep, colp);

   !if (re_bsearch (Error_Regexp))
     {
	bob ();
	return 0;
     }

   @filep = regexp_nth_match (1);	% file name
   @linep = regexp_nth_match (2);	% line number (string)
   @colp  = regexp_nth_match (3);	% column number (string)

   1;
}

public define compile_parse_errors ()
{
   compile_parse_errors_dir (&compile_find_next_error_fun, &go_down_1);
}

public define compile_previous_error ()
{
   compile_parse_errors_dir (&compile_find_prev_error_fun, &bol);
}

public define compile ()
{
   variable b, n;
   variable cmd = NULL;
   
   if (_NARGS != 0)
     cmd = ();

   b = whatbuf();
   call ("save_some_buffers");

   if (cmd == NULL) do_shell_cmd ();
   else shell_perform_cmd (cmd, 0);

   bob();
   pop2buf(b);

   compile_parse_errors ();
}

%
%  Parse current buffer as error output
%
public define compile_parse_buf ()
{
   Compile_Output_Buffer = whatbuf();
   bob ();
   compile_parse_errors ();
}

$1 = "acompile.sl";
if (is_defined ("get_process_input"))
{
   () = evalfile ($1);
}


% The current implementation for the database uses an associative array.
private variable Compiler_Database = Assoc_Type [Any_Type, NULL];

public define compile_select_compiler (name)
{
   variable c;
   c = Compiler_Database[name];
   if (c == NULL)
     verror ("Compiler %s is not supported.  See compile.sl for more information", name);
   Error_Regexp = c;
}

public define compile_add_compiler (name, regexp)
{
   Compiler_Database [name] = regexp;
}

%---------------------------------------------------------------------------
% Compiler database
%---------------------------------------------------------------------------
%Borland bcc/tcc compilers
%Error foo.c 4: Undefined symbol 'x' in function main
%Warning foo.c 34: Possible use of 'y' before definition in function main
compile_add_compiler ("bcc", "^[EW][a-r]+ \\(.+\\) \\(\\d+\\):\\(\\)");
compile_add_compiler ("tcc", "^[EW][a-r]+ \\(.+\\) \\(\\d+\\):\\(\\)");
%--------------------------------------------------------------------------
%Ultrix cc compiler
%ccom: Error: t.c, line 14: LC_ALL undefined
compile_add_compiler ("ultrix_cc", "[WE][ar][r][no][ir]n?g?: +\\(.+\\), line \\(\\d+\\):\\(\\)");
%--------------------------------------------------------------------------
%hp cc compiler
%cc: "t.c", line 3: error 1588: "ddkldkjdldkj" undefined.
compile_add_compiler ("hp_cc", "^cc: +\\\"\\(.+\\)\\\", line \\(\\d+\\):\\(\\)");
%--------------------------------------------------------------------------
%Sun acc compiler
%"filename.c", line 123: error: buffer undefined
%"filename.c", line 123: warning: fin not used
compile_add_compiler ("sun_acc", "^\\\"\\(.+\\)\\\", line \\(\\d+\\):\\(\\)");
%--------------------------------------------------------------------------
%AIX compiler, which may be referenced under any of these names.
%The Fortran compiler has the same format, so allow that too
%"foo.c", line 13.4: 1506-045 (S) Undeclared identifier bar.
%"foo.f", line 21.20: 1515-019 (S) Syntax is incorrect.
%@aix;
%@xlc;
%@xlf;
compile_add_compiler ("aix", "^\\\"\\(.+\\)\\\", line \\(\\d+\\)\\.\\(\\d+\\)");
compile_add_compiler ("xlc", "^\\\"\\(.+\\)\\\", line \\(\\d+\\)\\.\\(\\d+\\)");
compile_add_compiler ("xlf", "^\\\"\\(.+\\)\\\", line \\(\\d+\\)\\.\\(\\d+\\)");
%--------------------------------------------------------------------------
%The GNU compiler
%cmds.adb:33:20: ';' expected.
%cmds.c:33: warning: initialization of non-const * pointer...
%cmds.c:1041 (cmds.o): Undefined symbol _Screen_Height referenced...
%In file included from /usr/local/src/jed/src/xterm.c:10:
compile_add_compiler ("gcc", "^\\([^ :]+\\):\\(\\d+\\)[^:]*:\\(\\d*\\)");
%--------------------------------------------------------------------------
%The WATCOM compiler wcc
%keymap.c(71): Error! E1011: Symbol 'show_memory' has not been declared
%event.c(22): Warning! W202: Symbol 'xx' has been defined, but not referenced
%Warning(1028): PhGetMsgSize_ is an undefined reference
%file event.o(/home/qnx/rwm/photon/event.c): undefined symbol PhAttach_
compile_add_compiler ("wcc", "^\\(.+\\)(\\(\\d+\\)): [EW].+[rg]! [EW]\\d+:\\(\\)");
%--------------------------------------------------------------------------
%The Java compiler javac
%Test.java:151: Method getNumber() not found in class java.lang.String.
%@javac;
compile_add_compiler ("javac", "^\\(.+\\):\\(\\d+\\):\\(\\)");
%--------------------------------------------------------------------------
%Microsoft Visual C
%cob.cpp(30) : warning C4091: no symbols were declared
%cob.cpp(32) : error C2665: 'COBFileHeader::COBFileHeader' : none of the
%2 overloads can convert parameter 1 from type 'char [34]' (new behavior;
%please see help)
%cob.cpp(38) : warning C4091: no symbols were declared
%cob.cpp(45) : warning C4091: no symbols were declared
%cob.cpp(50) : error C2239: unexpected token '{' following declaration of
%'COBChunkHead'
%@vc;
%compile_add_compiler ("vc", "^\\(.+\\)(\\(\\d+\\)) : [ew].+:\\(\\)");
%--------------------------------------------------------------------------
%Microsoft Visual C
%cob.cpp(30) : warning C4091: no symbols were declared
%cob.cpp(32) : error C2665: 'COBFileHeader::COBFileHeader' : none of the
%c:\work\library\terrain\lodland.h(12) : fatal error C1083: Cannot open include file: 'fallocr.h': No such file or directory
%c:\work\library\terrain\lodvrtx.h(62) : see declaration of 'public: static class lodland_vertex_generator *  lodvertex::gen'
%@vc;
compile_add_compiler ("vc", "^[ \t]*\\(.+\\)(\\(\\d+\\)) : .*");
%--------------------------------------------------------------------------
%rgbds gameboy assembler
%*ERROR*	GBC_Main.s(1) :
%*ERROR*	GBC_Main.s(10) -> GBC_Hardware.h(27) :=0D
%*ERROR* : Worldsys.s(366) : Value must be 8-bit
%@rgbds;
compile_add_compiler ("rgbds", "^\\*ERROR\\*.*[\t ]\\(.+\\)(\\(\\d+\\))");

%---------------------------------------------------------------------------
% End of data base
%---------------------------------------------------------------------------

%!%+
%\variable{Compile_Default_Compiler}
%\usage{variable Compile_Default_Compiler = "gcc";}
%\description
%  This variable specifies the default compiler to be assumed when parsing
%  error messages in the compile buffer.  If not set, "gcc" is assumed.
%  Currently supported compilers include:
%#v+
%      gcc              (GNU C Compiler)
%      bcc              (Borland C Compiler)
%      tcc              (Turbo C Compiler)
%      ultrix_cc        (Ultrix C Compiler)
%      hp_cc            (HP C compiler)
%      sun_acc          (Sun ANSI C compiler)
%      aix, xlc, xlf    (Various AIX C compilers)
%      wcc              (Watcom C compiler)
%      javac            (Java Compiler)
%      vc               (Microsoft Visual C)
%#v-
%\notes
%  The primary purpose of this variable is to select a compiler prior to 
%  loading compile.sl.  Once compile.sl has been loaded, the value of this
%  variable has no effect.  To switch compilers, the \var{compile_select_compiler}
%  function must be used.
%\seealso{compile_select_compiler, compile_add_compiler}
%!%-
custom_variable ("Compile_Default_Compiler", "gcc");

compile_select_compiler (Compile_Default_Compiler);
