require 'sinatra'
require 'sinatra/reloader'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'
require_relative './model.rb'

enable :sessions

get('/') do
    db = SQLite3::Database.new("db/mml_db.db")
    db.results_as_hash = true
    album_hash = (db.execute("SELECT title, type, release_date, name, artist_id, album_id, artist_album_rel.id FROM album INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist.id = artist_album_rel.artist_id"))[0]
    slim(:index, locals:{album_hash:album_hash})
    
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

    input_album_id = (db.execute("SELECT id FROM album WHERE title = ?", album_title))[0] #id för albumet som heter det som skrivits i formuläret, om det finns
    input_artist_id = (db.execute("SELECT id FROM artist WHERE name = ?", artist_name))[0]  #id för artisten som heter det som skrivits i formuläret, om det finns
    art_alb_rel_empty = (db.execute("SELECT id FROM artist_album_rel WHERE artist_id = ? AND album_id = ?", input_artist_id, input_album_id)).empty? #boolean för om det finns en artist/album kombo som specifierats


    p "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA:"
    p input_album_id
    p input_artist_id
    p art_alb_rel_empty

    if art_alb_rel_empty #om kombon inte finns

        #lägg in albumets titel, typ och release date i album-tabellen
        db.execute("INSERT INTO album (title, type, release_date) VALUES (?, ?, ?)", album_title, album_type, release_date)

        if input_artist_id == nil
            #om artisten inte finns -> lägg in artisten i 
            db.execute("INSERT INTO artist (name) VALUES (?)", artist_name)
        end

        new_artist_id = (db.execute("SELECT id FROM artist WHERE name = ?", artist_name))[0] #id för artisten som specifierats
        new_album_id = (db.execute("SELECT id FROM album WHERE title = ?", album_title))[0] #id för albumet som specifierats

        #lägg in i relationstabellen id:n för album och artist
        db.execute("INSERT INTO artist_album_rel (artist_id, album_id) VALUES (?, ?)", new_artist_id, new_album_id)
    end
    redirect('/albums')
end

get('/albums') do
    db = SQLite3::Database.new("db/mml_db.db")
    db.results_as_hash = true
    album_hash = db.execute("SELECT title, type, release_date, name AS artist_name, artist_id, album_id, artist_album_rel.id AS rel_id FROM album INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist.id = artist_album_rel.artist_id")
    p album_hash
    slim(:"albums/index",locals:{album_hash:album_hash})
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

post('/albums/:id/update') do
    album_title = params[:album_title]
    artist_name = params[:artist_name]
    album_type = params[:album_type]
    release_date = params[:release_date]
    old_album_id = (params[:id]).to_i
    db = SQLite3::Database.new("db/mml_db.db")

    input_album_id = (db.execute("SELECT id FROM album WHERE title = ?", album_title))[0]
    input_artist_id = (db.execute("SELECT id FROM artist WHERE name = ?", artist_name))[0] #de (eventuella) album & artister som matchar namn som specifierats i formuläret. 

    art_alb_rel_empty = (db.execute("SELECT id FROM artist_album_rel WHERE artist_id = ? AND album_id = ?", input_artist_id, input_album_id)).empty?

    if art_alb_rel_empty #om artist & album kombon inte finns:
        db.execute("UPDATE album SET title = ?, type = ?, release_date = ? WHERE id = ?", album_title, album_type, release_date, old_album_id)
        
        #uppdatera titel, typ, och release date för albumet med id:t från formuläret.

        if input_artist_id == nil
            #artisten finns inte -> lägg in artisten
            db.execute("INSERT INTO artist (name) VALUES (?)", artist_name)
        end
        new_artist_id = db.execute("SELECT id FROM artist WHERE name = ?", artist_name)
        #lägg in i relationstabellen
        db.execute("UPDATE artist_album_rel SET artist_id = ? WHERE album_id = ?", new_artist_id, old_album_id)

    else
        db.execute("UPDATE album SET title = ?, type = ?, release_date = ? WHERE id = ?", album_title, album_type, release_date, old_album_id)
    end

    redirect('/albums')
end

get('/register') do

    slim(:"/register")
end

post('/users/new') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
    db = SQLite3::Database.new("db/mml_db.db")
    username_empty = (db.execute("SELECT username FROM user WHERE username = ?", username)).empty?
    p username_empty

    if password == password_confirm && username_empty
        #registrera
        
        password_digest = BCrypt::Password.create(password)
        p password_digest
        current_date = (Time.now).strftime("%Y-%m-%d")
        db.execute("INSERT INTO user (role, username, password_digest, register_date) VALUES (?, ?, ?, ?)", "plebian", username, password_digest, current_date)
        redirect('/')
  
    else
        #felhantering
        raise("cringe")
    end
end

get('/login') do

    slim(:"/login")
end

post('/login') do
    username = params[:username]
    password = params[:password]
    db = SQLite3::Database.new("db/mml_db.db")
    db.results_as_hash = true
    selected_user = db.execute("SELECT * FROM user WHERE username = ?", username)[0]
    user_password_digest = selected_user["password_digest"]
    if selected_user != nil

        if BCrypt::Password.new(pwdigest) == password
            session[:id] = id
            redirect('/todos')
            else
            p "wrong password"
            redirect('/login')
            end
    else
        p "wrong username"
        redirect('/login')
    end
    redirect('/')
end