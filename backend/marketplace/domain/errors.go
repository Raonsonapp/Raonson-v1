package domain

import "errors"

// ErrAlreadyInState — объект аллакай дар ҳамон ҳолат аст.
// Ин ХАТО нест: webhook метавонад ду бор ояд ва коркард бояд
// бехатар (идемпотент) бошад. Даъваткунанда онро ҳамчун "ҳеҷ кор
// лозим нест" мешуморад.
var ErrAlreadyInState = errors.New("domain: аллакай дар ҳамин ҳолат")

// ErrForbidden — корбар ба ин объект дастрасӣ надорад.
var ErrForbidden = errors.New("domain: дастрасӣ нест")

// ErrNotFound — объект ёфт нашуд.
var ErrNotFound = errors.New("domain: ёфт нашуд")
