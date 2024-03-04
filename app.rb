require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require_relative './model.rb'

get('/') do
    slim(:index)
end

get('/albums/new') do
    slim(:"albums/new")
end

post('/albums') do
    album_title = params[:album_title]
    artist_name = params[:artist_name]
    album_type = params[:album_type]
    release_date = params[:release_date]
    db = SQLite3::Database.new("db/mml_db.db")

    album_id = (db.execute("SELECT id FROM album WHERE title = ?", album_title))[0]
    artist_id = (db.execute("SELECT id FROM artist WHERE name = ?", artist_name))[0]
    art_alb_rel_empty = (db.execute("SELECT id FROM artist_album_rel WHERE artist_id = ? AND album_id = ?", artist_id, album_id)).empty?

    p "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:"
    p album_id
    p artist_id
    p art_alb_rel_empty

    if art_alb_rel_empty
        db.execute("INSERT INTO album (title, type, release_date) VALUES (?, ?, ?)", album_title, album_type, release_date)
        db.execute("INSERT INTO artist (name) VALUES (?)", artist_name)

        new_artist_id = (db.execute("SELECT id FROM artist WHERE name = ?", artist_name))[0]
        new_album_id = (db.execute("SELECT id FROM album WHERE title = ?", album_title))[0]

        db.execute("INSERT INTO artist_album_rel (artist_id, album_id) VALUES (?, ?)", new_artist_id, new_album_id)
    end
    redirect('/')
end

get('/albums') do
    db = SQLite3::Database.new("db/mml_db.db")
    db.results_as_hash = true
    all_alb = db.execute("SELECT * FROM album")
    all_art = db.execute("SELECT * FROM artist")
    all_alb_art_rel = db.execute("SELECT * FROM artist_album_rel")
    slim(:"albums/browse",locals:{album_list:all_alb, artist_list:all_art, relation_list:all_alb_art_rel})
end