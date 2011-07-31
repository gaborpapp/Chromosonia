#ifdef STATIC_LINK
Scheme_Object *sonotopy_scheme_reload(Scheme_Env *env);
#else
Scheme_Object *scheme_reload(Scheme_Env *env);
#endif
