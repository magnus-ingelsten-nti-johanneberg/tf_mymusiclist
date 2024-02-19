require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'

get('/') do
    slim(:index)
end

get('/album/new') do
    slim(:"album/new")
end

post('/album/new') do
    slim(:"album/new")
end