package main

import (
	"github.com/go-martini/martini"
	"net/http"
	"conf"
	"controllers"
	"models"
	"utils"
)

func main() {
	m := martini.Classic()

	m.Use(func(w http.ResponseWriter) {
		w.Header().Set("Content-Type", "application/json; charset=utf-8")
	})

	m.Map(new(utils.MarshUnmarsh))

	Auth := func(mu *utils.MarshUnmarsh, req *http.Request, rw http.ResponseWriter) {
		reqUserId := req.Header.Get("X-Auth-User")
		reqToken  := req.Header.Get("X-Auth-Token")
		if !models.CheckToken(reqUserId, reqToken) {
			rw.WriteHeader(http.StatusUnauthorized)
			rw.Write(mu.Marshal(conf.ErrUserAccessDenied))
		}
	}

	// ROUTES
	m.Get("/", controllers.Home)

	// users
	m.Get("/api/v1/users", controllers.GetUsers)
	m.Get("/api/v1/users/:id", controllers.GetUserById)
	m.Post("/api/v1/users", controllers.CreateUser)
	// …

	// posts
	m.Get("/api/v1/posts", controllers.GetRootPosts)
	m.Get("/api/v1/posts/:id", controllers.GetPostById)
	m.Post("/api/v1/posts", Auth, controllers.CreatePost)
	// …

	m.Run()
}