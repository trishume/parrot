#ifndef SERIALIZATIONCONTEXT_H_GUARD
#define SERIALIZATIONCONTEXT_H_GUARD

PMC * SC_get_sc(PARROT_INTERP, STRING *handle);
void SC_set_sc(PARROT_INTERP, STRING *handle, PMC *sc);

#endif
