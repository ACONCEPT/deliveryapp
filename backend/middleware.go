package main

import (
	"log"
	"net/http"
	"time"
)

// CORSMiddleware handles CORS headers for all requests
// This middleware is intentionally permissive for development and internal use
func CORSMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Allow requests from any origin
		origin := r.Header.Get("Origin")
		if origin == "" {
			origin = "*"
		}
		w.Header().Set("Access-Control-Allow-Origin", origin)

		// Allow credentials (cookies, authorization headers, etc.)
		w.Header().Set("Access-Control-Allow-Credentials", "true")

		// Allow all common HTTP methods
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD")

		// Allow all common headers plus any custom headers
		w.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, Authorization, X-CSRF-Token, X-Requested-With, Origin, Access-Control-Request-Method, Access-Control-Request-Headers")

		// Expose headers that the client can access
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Type, Authorization")

		// Cache preflight response for 24 hours
		w.Header().Set("Access-Control-Max-Age", "86400")

		// Handle preflight OPTIONS requests
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

// LoggingMiddleware logs incoming requests
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Log request
		log.Printf("[%s] %s %s", r.Method, r.URL.Path, r.RemoteAddr)

		// Call next handler
		next.ServeHTTP(w, r)

		// Log duration
		log.Printf("[%s] %s completed in %v", r.Method, r.URL.Path, time.Since(start))
	})
}

// RecoveryMiddleware recovers from panics
func RecoveryMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				log.Printf("Panic recovered: %v", err)
				http.Error(w, "Internal Server Error", http.StatusInternalServerError)
			}
		}()

		next.ServeHTTP(w, r)
	})
}
