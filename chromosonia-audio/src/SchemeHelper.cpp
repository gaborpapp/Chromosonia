// Copyright (C) 2007 Dave Griffiths
//
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

#include <assert.h>
#include "SchemeHelper.h"

using namespace std;
using namespace SchemeHelper;

float SchemeHelper::FloatFromScheme(Scheme_Object *ob)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, ob);
	MZ_GC_REG();
	float ret=(float)scheme_real_to_double(ob);
	MZ_GC_UNREG();
	return ret;
}

double SchemeHelper::DoubleFromScheme(Scheme_Object *ob)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, ob);
	MZ_GC_REG();
	double ret=scheme_real_to_double(ob);
	MZ_GC_UNREG();
	return ret;
}

int SchemeHelper::IntFromScheme(Scheme_Object *ob)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, ob);
	MZ_GC_REG();
	int ret=SCHEME_INT_VAL(ob);
	MZ_GC_UNREG();
	return ret;
}

bool SchemeHelper::BoolFromScheme(Scheme_Object *ob)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, ob);
	MZ_GC_REG();
	bool ret=SCHEME_TRUEP(ob);
	MZ_GC_UNREG();
	return ret;
}

string SchemeHelper::StringFromScheme(Scheme_Object *ob)
{
	char *ret = NULL;
	MZ_GC_DECL_REG(2);
	MZ_GC_VAR_IN_REG(0, ob);
	MZ_GC_VAR_IN_REG(1, ret);
	MZ_GC_REG();
	ret = scheme_utf8_encode_to_buffer(SCHEME_CHAR_STR_VAL(ob), SCHEME_CHAR_STRLEN_VAL(ob), NULL, 0);
	MZ_GC_UNREG();
	return string(ret);
}

string SchemeHelper::PathFromScheme(Scheme_Object *ob)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, ob);
	MZ_GC_REG();
	string ret;
	if (SCHEME_PATHP(ob))
	{
		ret = SCHEME_PATH_VAL(ob);
	}
	else
	{
		ret = StringFromScheme(ob);
	}
	MZ_GC_UNREG();
	return ret;
}

void SchemeHelper::FloatsFromScheme(Scheme_Object *src, float *dst, unsigned int size)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, src);
	MZ_GC_REG();
	assert(size<=(unsigned int)SCHEME_VEC_SIZE(src));
	for (unsigned int n=0; n<size; n++)
	{
		dst[n]=scheme_real_to_double(SCHEME_VEC_ELS(src)[n]);
	}
	MZ_GC_UNREG();
}

Scheme_Object *SchemeHelper::FloatsToScheme(float *src, unsigned int size)
{
	Scheme_Object *ret=NULL;
	Scheme_Object *tmp=NULL;
	MZ_GC_DECL_REG(2);
	MZ_GC_VAR_IN_REG(0, ret);
	MZ_GC_VAR_IN_REG(1, tmp);
	MZ_GC_REG();
	ret = scheme_make_vector(size, scheme_void);
	for (unsigned int n=0; n<size; n++)
	{
		tmp=scheme_make_double(src[n]);
		SCHEME_VEC_ELS(ret)[n]=tmp;
	}
	MZ_GC_UNREG();
	return ret;
}

bool SchemeHelper::IsSymbol(Scheme_Object *src, const string &symbol)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, src);
	MZ_GC_REG();
	bool ret = SAME_OBJ(src, scheme_intern_symbol(symbol.c_str()));
	MZ_GC_UNREG();
	return ret;
}

string SchemeHelper::SymbolName(Scheme_Object *src)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, src);
	MZ_GC_REG();
	string ret = scheme_symbol_name(src);
	MZ_GC_UNREG();
	return ret;
}

vector<int> SchemeHelper::IntVectorFromScheme(Scheme_Object *src)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, src);
	MZ_GC_REG();

	vector<int> ret;
	for (int n=0; n<SCHEME_VEC_SIZE(src); n++)
	{
		if (SCHEME_EXACT_INTEGERP(SCHEME_VEC_ELS(src)[n]))
		{
			ret.push_back(IntFromScheme(SCHEME_VEC_ELS(src)[n]));
		}
	}
	MZ_GC_UNREG();
	return ret;
}

vector<float> SchemeHelper::FloatVectorFromScheme(Scheme_Object *src)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, src);
	MZ_GC_REG();

	vector<float> ret;
	for (int n=0; n<SCHEME_VEC_SIZE(src); n++)
	{
		if (SCHEME_NUMBERP(SCHEME_VEC_ELS(src)[n]))
		{
			ret.push_back(FloatFromScheme(SCHEME_VEC_ELS(src)[n]));
		}
	}
	MZ_GC_UNREG();
	return ret;
}

void SchemeHelper::ArgCheck(const string &funcname, const string &format, int argc, Scheme_Object **argv)
{
	MZ_GC_DECL_REG(1);
	MZ_GC_VAR_IN_REG(0, argv);
	MZ_GC_REG();

	// wrong number of arguments, could mean optional arguments for this function,
	// just give up in this case for now...

	//if(argc==(int)format.size())
	{
		for (unsigned int n=0; n<format.size(); n++)
		{
			switch(format[n])
			{
				case 'f':
					if (!SCHEME_NUMBERP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "number", n, argc, argv);
					}
				break;

				case 'v':
					if (!SCHEME_VECTORP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "vector", n, argc, argv);
					}
					if (SCHEME_VEC_SIZE(argv[n])!=3 && SCHEME_VEC_SIZE(argv[n])!=4)
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "vector size 3 or 4", n, argc, argv);
					}
				break;

				case 'c':
					if ((!SCHEME_VECTORP(argv[n]) || ((SCHEME_VEC_SIZE(argv[n])!=2) &&
						 (SCHEME_VEC_SIZE(argv[n])!=3) && (SCHEME_VEC_SIZE(argv[n])!=4))) &&
						(!SCHEME_NUMBERP(argv[n])))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "vector size 2, 3, 4, or number",
								n, argc, argv);
					}
				break;

				case 'q':
					if (!SCHEME_VECTORP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "vector", n, argc, argv);
					}
					if (SCHEME_VEC_SIZE(argv[n])!=4)
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "quat (vector size 4)", n, argc, argv);
					}
				break;

				case 'm':
					if (!SCHEME_VECTORP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "vector", n, argc, argv);
					}
					if (SCHEME_VEC_SIZE(argv[n])!=16)
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "matrix (vector size 16)", n, argc, argv);
					}
				break;

				case 'i':
					if (!SCHEME_INTP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "int", n, argc, argv);
					}
				break;

				case 's':
					if (!SCHEME_CHAR_STRINGP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "string", n, argc, argv);
					}
				break;

				case 'l':
					if (!SCHEME_LISTP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "list", n, argc, argv);
					}
				break;

				case 'S':
					if (!SCHEME_SYMBOLP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "symbol", n, argc, argv);
					}
				break;

				case 'b':
					if (!SCHEME_BOOLP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "boolean", n, argc, argv);
					}
				break;

				case 'k':
					if (!SCHEME_KEYWORDP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "keyword", n, argc, argv);
					}
				break;

				case 'p': // path or string
					if (!SCHEME_CHAR_STRINGP(argv[n]) && !SCHEME_PATHP(argv[n]))
					{
						MZ_GC_UNREG();
						scheme_wrong_type(funcname.c_str(), "path or string", n, argc, argv);
					}
				break;


				case '?':
				break;

				default:
					assert(false);
				break;
			};
		}
	}
	MZ_GC_UNREG();
}

