require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/flash'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'
require_relative './model.rb'

enable :sessions

helpers do
    def albums_hash #albums_hash är TITEL, TYP, RELEASE_DATE, ARTIST_NAME, ARTIST_ID, ALBUM_ID, REL_ID på SAMTLIGA ALBUM
        db = db_connect("db/mml_db.db")
        result = db.execute("SELECT title, type, release_date, name AS artist_name, artist_id, album_id, artist_album_rel.id AS rel_id FROM album INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist.id = artist_album_rel.artist_id")
        return result
    end
    def avg_score_hash
        db = db_connect("db/mml_db.db")
        albums_hash = db.execute("SELECT title, type, release_date, name AS artist_name, artist_id, album_id, artist_album_rel.id AS rel_id FROM album INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist.id = artist_album_rel.artist_id")
        result = {}
        for album in albums_hash
            result["#{album['album_id']}"] = (db.execute("SELECT AVG(rating) AS avg FROM user_album_rel WHERE rating >= 1 AND album_id = ?", album['album_id'])[0])['avg']
        end
        return result
    end
    def scores
        possible_scores = ["masterpiece", "great", "very good", "good", "fine", "average", "bad", "very bad", "horrible", "appalling"]
        return possible_scores
    end
    def active_user_album_rel_hash(album_id)
        if $logged_in
            db = db_connect("db/mml_db.db")
            result = db.execute("SELECT title, user_id, album_id, is_favorite, rating, user_album_rel.id AS rel_id FROM album INNER JOIN user_album_rel ON album.id = user_album_rel.album_id INNER JOIN user ON user.id = user_album_rel.user_id WHERE album_id = ? AND user_id = ?", album_id, $user['id'])[0]
        end
        return result
    end
end
   
before do
    $user = session[:current_user]
    $logged_in = is_logged_in($user)
    $db = db_connect("db/mml_db.db")
    p "before: #{$user}, #{$logged_in}"

end

get('/') do
    p "logged in : #{$logged_in}"
    db = db_connect("db/mml_db.db")
    slim(:index, locals:{user_hash:$user, logged_in:$logged_in})
    
end

before('/albums/new') do
    if !$logged_in
        flash[:notice] = "You need admin permissions for this."
        redirect('/')
    elsif $user['role'] != "admin"
        flash[:notice] = "You need admin permissions for this."
        redirect('/')
    end
end

get('/albums/new') do
    slim(:"albums/new", locals:{user_hash:$user, logged_in:$logged_in})
end

post('/albums') do
    album_title = params[:album_title]
    artist_name = params[:artist_name]
    album_type = params[:album_type]
    release_date = params[:release_date]
    db = db_connect("db/mml_db.db")

    input_album_id = (db.execute("SELECT id FROM album WHERE title = ?", album_title))[0] #id för albumet som heter det som skrivits i formuläret, om det finns
    input_artist_id = (db.execute("SELECT id FROM artist WHERE name = ?", artist_name))[0]  #id för artisten som heter det som skrivits i formuläret, om det finns
    art_alb_rel_empty = (db.execute("SELECT id FROM artist_album_rel WHERE artist_id = ? AND album_id = ?", input_artist_id, input_album_id)).empty? #boolean för om det finns en artist/album kombo som specifierats

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
    db = db_connect("db/mml_db.db")

    slim(:"albums/index",locals:{album_hash:albums_hash, user_hash:$user, logged_in:$logged_in})
end

post('/albums/:id/delete') do
    album_id = params[:id].to_i
    db = db_connect("db/mml_db.db")

    db.execute("DELETE FROM album WHERE id = ?", album_id)
    db.execute("DELETE FROM artist_album_rel WHERE album_id = ?", album_id)
    db.execute("DELETE FROM user_album_rel WHERE album_id = ?", album_id)
    redirect('/albums')
end

get('/albums/:id/edit') do

    album_id = params[:id].to_i
    db = db_connect("db/mml_db.db")

    album_hash = (db.execute("SELECT title, type, release_date, name, artist_id, album_id, artist_album_rel.id FROM album INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist.id = artist_album_rel.artist_id WHERE album_id = ?", album_id))[0]
    
    p "aaaa"
    p db
    p album_hash

    slim(:"albums/edit", locals:{id:album_id, album_hash:album_hash, user_hash:$user, logged_in:$logged_in})
end

post('/albums/:id/update') do
    album_title = params[:album_title]
    artist_name = params[:artist_name]
    album_type = params[:album_type]
    release_date = params[:release_date]
    old_album_id = (params[:id]).to_i
    db = db_connect("db/mml_db.db")

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
    slim(:"/register", locals:{user_hash:$user, logged_in:$logged_in})
end

post('/users/new') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
    db = db_connect("db/mml_db.db")
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
    slim(:"/login", locals:{user_hash:$user, logged_in:$logged_in})
end

post('/login') do
    username = params[:username]
    password = params[:password]
    db = db_connect("db/mml_db.db")

    selected_user = db.execute("SELECT * FROM user WHERE username = ?", username)[0]

    if user_exists(selected_user)
        user_password_digest = selected_user["password_digest"]
        if BCrypt::Password.new(user_password_digest) == password
            session[:current_user] = selected_user
            p session[:current_user]
            redirect('/')
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

get('/logout') do
    session.clear
    redirect('/')
end

get('/profile/:profile_username') do
    profile_name = params[:profile_username]
    db = db_connect("db/mml_db.db")
    maybe_user = db.execute("SELECT * FROM user WHERE username = ?", profile_name)[0]

    user_albums = (db.execute("SELECT title, type, release_date, role, username, user_id, album_id, is_favorite, rating, user_album_rel.id FROM album INNER JOIN user_album_rel ON album.id = user_album_rel.album_id INNER JOIN user ON user.id = user_album_rel.user_id WHERE user_id = ?", maybe_user['id']))

    if maybe_user != nil
        slim(:"/profile", locals:{user_hash:$user, logged_in:$logged_in, profile_user:maybe_user, user_albums:user_albums})
    else
        slim(:"/error", locals:{user_hash:$user, logged_in:$logged_in, profile_user:maybe_user})
    end
end

get('/album/:album_id/:album_title') do
    album_title = params[:album_title].gsub('_', ' ')
    album_id = params[:album_id].to_i
    db = db_connect("db/mml_db.db")

    possible_album = db.execute("SELECT * FROM album WHERE id = ?", album_id)

    #hämtar all data om ett album, inklusive vem som har det som favorite, ratings, etc.
    maybe_album = (db.execute("SELECT title, type, release_date, name, role, username, user.id AS user_id, album.id AS album_id, is_favorite, rating, user_album_rel.id AS rel_id FROM album LEFT JOIN user_album_rel ON album.id = user_album_rel.album_id LEFT JOIN user ON user.id = user_album_rel.user_id LEFT JOIN artist_album_rel ON album.id = artist_album_rel.album_id LEFT JOIN artist ON artist_album_rel.artist_id = artist.id WHERE artist_album_rel.album_id = ?", album_id))[0]

    user_album_relations = db.execute("SELECT * FROM user_album_rel WHERE album_id = ?", album_id)[0]
    if user_album_relations != nil
        favorites = db.execute("SELECT COUNT(is_favorite) AS number_of_favorites FROM user_album_rel WHERE is_favorite == 1 AND album_id = ?", album_id)[0]
        average_rating = db.execute("SELECT AVG(rating) AS avg FROM user_album_rel WHERE rating >= 1 AND album_id = ?", album_id)[0]
    else
        favorites = {}
        average_rating = {}
        favorites['number_of_favorites'] = 0
        average_rating['avg'] = 0
    end

    if possible_album != nil #albumet finns
        slim(:"/albums/show", locals:{user_hash:$user, logged_in:$logged_in, page_album_hash:maybe_album, favorites:favorites['number_of_favorites'], score:average_rating['avg'].round(2), album_id:album_id})
    else
        slim(:"/error", locals:{user_hash:$user, logged_in:$logged_in})
    end
 
end

post('/album/:album_id/rating/update') do
    album_id = params[:album_id].to_i
    rating = params[:album_score].to_i
    db = db_connect("db/mml_db.db")

    album_hash = (db.execute("SELECT title, type, release_date, name, artist_id, album_id, artist_album_rel.id FROM album INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist.id = artist_album_rel.artist_id WHERE album_id = ?", album_id))[0]
    album_title = album_hash['title'].gsub(' ', '_')
   
    user_doesnt_have_rating = (db.execute("SELECT id FROM user_album_rel WHERE user_id = ? AND album_id = ?", $user['id'], album_id)[0]).nil?

    if user_doesnt_have_rating && rating != 0
        #lägg in rating och idn
        db.execute("INSERT INTO user_album_rel (rating, user_id, album_id) VALUES (?, ?, ?)", rating, $user['id'], album_id)
    else
        #uppdatera rating & idn
        db.execute("UPDATE user_album_rel SET rating = ? WHERE user_id = ? AND album_id = ?", rating, $user['id'], album_id)
    end

    redirect back
end

post('/album/:album_id/favorite/update') do
    album_id = params[:album_id].to_i
    favorite_toggle = params[:favorite_toggle]

    if favorite_toggle == "remove from favorites"
        $db.execute("UPDATE user_album_rel SET is_favorite = 0 WHERE user_id = ? AND album_id = ?", $user['id'], album_id)
    elsif favorite_toggle == "add to favorites"
        $db.execute("UPDATE user_album_rel SET is_favorite = 1 WHERE user_id = ? AND album_id = ?", $user['id'], album_id)
    end

    redirect back
end

get('/albumlist/:username') do
    list_username = params[:username]
    db = db_connect("db/mml_db.db")

    maybe_user = db.execute("SELECT * FROM user WHERE username = ?", list_username)[0]

    user_albums = (db.execute("SELECT title, type, release_date, name, role, username, user_id, user_album_rel.album_id, is_favorite, rating, user_album_rel.id FROM album INNER JOIN user_album_rel ON album.id = user_album_rel.album_id INNER JOIN user ON user.id = user_album_rel.user_id INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist_album_rel.artist_id = artist.id WHERE user_id = ?", maybe_user['id']))

    slim(:"/albumlist", locals:{user_hash:$user, logged_in:$logged_in, user_albums:user_albums})
end