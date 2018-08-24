package conf

import (
	"net/http"
)

type ApiError struct {
	Code        int    `json:"errorCode"`
	HttpCode    int    `json:"-"`
	Message     string `json:"errorMsg"`
	Info        string `json:"errorInfo"`
}

func (e *ApiError) Error() string {
	return e.Message
}

func NewApiError(err error) *ApiError {
	return &ApiError{0, http.StatusInternalServerError, err.Error(), ""}
}

var ErrUserPassEmpty = &ApiError{110, http.StatusBadRequest, "Password is empty", ""}
var ErrUserNotFound  = &ApiError{123, http.StatusNotFound,   "User not found",    ""}
var ErrUserIdEmpty   = &ApiError{130, http.StatusBadRequest, "Empty User Id",     ""}
var ErrUserIdWrong   = &ApiError{131, http.StatusBadRequest, "Wrong User Id",     ""}
// … и т. д.