server "app1.ub.upb.de",     user: "ubpb", roles: ["app", "web"]
server "app2.ub.upb.de",     user: "ubpb", roles: ["app", "web"]
server "batch.ub.upb.de",    user: "ubpb", roles: ["app", "db", "jobs"]
set :branch, "production"
set :deploy_to, "/ubpb/course_manager"
