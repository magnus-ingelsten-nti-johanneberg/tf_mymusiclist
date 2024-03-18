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
    redirect('/albums')
end

get('/albums') do
    db = SQLite3::Database.new("db/mml_db.db")
    db.results_as_hash = true
    all_alb = db.execute("SELECT * FROM album")
    all_art = db.execute("SELECT * FROM artist")
    all_alb_art_rel = db.execute("SELECT * FROM artist_album_rel")
    slim(:"albums/index",locals:{album_list:all_alb, artist_list:all_art, relation_list:all_alb_art_rel})
end

post('/albums/:id/delete') do
    album_id = params[:id].to_i
    db = SQLite3::Database.new("db/mml_db.db")
    db.execute("DELETE FROM album WHERE id = ?", album_id)
    db.execute("DELETE FROM artist_album_rel WHERE album_id = ?", album_id)
    db.execute("DELETE FROM user_album_rel WHERE album_id = ?", album_id)
    redirect('/albums')
end

get('/albums/:id/edit') do
    album_id = params[:id].to_i
    db = SQLite3::Database.new("db/mml_db.db")
    db.results_as_hash = true
    album_hash = (db.execute("SELECT title, type, release_date, name, artist_id, album_id, artist_album_rel.id FROM album INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist.id = artist_album_rel.artist_id WHERE album_id = ?", album_id))[0]
    
    p "aaaa"
    p db
    p album_hash

    slim(:"albums/edit", locals:{id:album_id, album_hash:album_hash})
end