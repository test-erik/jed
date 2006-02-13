/* Copyright (c) 1992, 1998, 2000, 2002, 2003, 2004, 2005, 2006 John E. Davis
 * This file is part of JED editor library source.
 *
 * You may distribute this file under the terms the GNU General Public
 * License.  See the file COPYING for more information.
 */
/* It is too bad that this cannot be done at the preprocessor level.
 * Unfortunately, C is not completely portable yet.  Basically the #error
 * directive is the problem.
 */
#include "config.h"

#include <stdio.h>
#ifdef HAVE_STDLIB_H
# include <stdlib.h>
#endif
#ifdef VMS
# include <ssdef.h>
#endif
#include <slang.h>

#include "jdmacros.h"

#ifdef VMS
# define SUCCESS	1
# define FAILURE	2
#else
# define SUCCESS	0
# define FAILURE	1
#endif

static char *make_version (unsigned int v)
{
   static char v_string[16];
   unsigned int a, b, c;
   
   a = v/10000;
   b = (v - a * 10000) / 100;
   c = v - (a * 10000) - (b * 100);
   sprintf (v_string, "%u.%u.%u", a, b, c);
   return v_string;
}



int main (int argc, char **argv)
{
   unsigned int min_version, sl_version;
   unsigned int sug_version;
   int ret;
   
   if ((argc < 3) || (argc > 4))
     {
	fprintf (stderr, "Usage: %s <PGM> <SLANG-VERSION> <SUGG VERSION>\n", argv[0]);
	return FAILURE;
     }
#ifndef SLANG_VERSION
   sl_version = 0;
#else
   sl_version = SLANG_VERSION;
#ifdef REAL_UNIX_SYSTEM
   if (SLang_Version != SLANG_VERSION)
     {
	fprintf (stderr, "\n\n******\n");
	fprintf (stderr, "\
slang.h (version=%ld) does not match the slang library version (%ld)\n\
Did you install slang as a shared library?  Did you run ldconfig?\n\
Perhaps you need to set the RPATH variable in the Makefile.\n\
You have an installation problem and you will need to check the SLANG\n\
variables in the Makefile and properly set them.\n\
Also try: make clean; make\n", (long)SLANG_VERSION, (long)SLang_Version);
	fprintf (stderr, "******\n\n");
	return FAILURE;
     }
#endif
#endif
   
   sscanf (argv[2], "%u", &min_version);
   if (argc == 4) sscanf (argv[3], "%u", &sug_version);
   else sug_version = sl_version;

   ret = SUCCESS;
   if (sl_version < min_version)
     {
	fprintf (stderr, "This version of %s requires slang version %s.\n",
		 argv[1], make_version(min_version));
	
	ret = FAILURE;
     }
   
   if (sl_version < sug_version)
     {
	fprintf (stderr, "Your slang version is %s.\n", make_version(sl_version));
	fprintf (stderr, "To fully utilize this program, you should upgrade the slang library to\n");
	fprintf (stderr, "  version %s\n", make_version(sug_version));
	fprintf (stderr, "This library is available via anonymous ftp from\n\
space.mit.edu in pub/davis/slang.\n");
     }
   
   return ret;
}




