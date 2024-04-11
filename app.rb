require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/flash'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'
require_relative './model.rb'

enable :sessions
   
before do
    $user = session[:current_user]
    $logged_in = is_logged_in($user)
    $db = db_connect("db/mml_db.db")
    p "before: #{$user}, #{$logged_in}"

end

get('/') do
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

    add_album_full(album_title, artist_name, album_type, release_date)
    
    redirect('/albums')
end

get('/albums') do
    db = db_connect("db/mml_db.db")

    slim(:"albums/index",locals:{album_hash:albums_hash, user_hash:$user, logged_in:$logged_in})
end

post('/albums/:id/delete') do
    album_id = params[:id].to_i
    db = db_connect("db/mml_db.db")

    delete_album(album_id)
    redirect back
end

get('/albums/:id/edit') do

    album_id = params[:id].to_i
    db = db_connect("db/mml_db.db")

    album_hash = get_album_hash_by_id(album_id)
    
    slim(:"albums/edit", locals:{id:album_id, album_hash:album_hash, user_hash:$user, logged_in:$logged_in})
end

post('/albums/:id/update') do
    album_title = params[:album_title]
    artist_name = params[:artist_name]
    album_type = params[:album_type]
    release_date = params[:release_date]
    old_album_id = (params[:id]).to_i

    update_album_full(album_title, artist_name, album_type, release_date, old_album_id)

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

    if password == password_confirm && username_empty
        register_user(username, password)
        redirect('/')
    else
        flash[:notice] = "Unmatching passwords."
        redirect back
    end
end

get('/login') do
    slim(:"/login", locals:{user_hash:$user, logged_in:$logged_in})
end

post('/login') do
    username = params[:username]
    password = params[:password]

    login_func(username, password)
end

get('/logout') do
    session.clear
    redirect('/')
end

get('/profile/:profile_username') do
    profile_name = params[:profile_username]
    db = db_connect("db/mml_db.db")
    maybe_user = get_user_by_name(profile_name)

    if maybe_user != nil
        user_albums = get_user_albums_by_user_id(maybe_user['id'])
        slim(:"/profile", locals:{user_hash:$user, logged_in:$logged_in, profile_user:maybe_user, user_albums:user_albums})
    else
        slim(:"/error", locals:{user_hash:$user, logged_in:$logged_in, profile_user:maybe_user})
    end
end

#MVC behövs under här

get('/album/:id/:title') do
    album_title = params[:title].gsub('_', ' ')
    album_id = params[:id].to_i
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

post('/album/:id/rating/update') do
    album_id = params[:id].to_i
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

post('/album/:id/favorite/update') do
    album_id = params[:id].to_i
    favorite_toggle = params[:favorite_toggle]
    db = db_connect("db/mml_db.db")

    if favorite_toggle == "remove from favorites"
        db.execute("UPDATE user_album_rel SET is_favorite = 0 WHERE user_id = ? AND album_id = ?", $user['id'], album_id)
    elsif favorite_toggle == "add to favorites"
        db.execute("UPDATE user_album_rel SET is_favorite = 1 WHERE user_id = ? AND album_id = ?", $user['id'], album_id)
    end
    redirect back
end

get('/albumlist/:username') do
    list_username = params[:username]
    db = db_connect("db/mml_db.db")

    maybe_user = db.execute("SELECT * FROM user WHERE username = ?", list_username)[0]

    user_albums = (db.execute("SELECT title, type, release_date, name, role, username, user_id, user_album_rel.album_id, is_favorite, rating, user_album_rel.id FROM album INNER JOIN user_album_rel ON album.id = user_album_rel.album_id INNER JOIN user ON user.id = user_album_rel.user_id INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist_album_rel.artist_id = artist.id WHERE user_id = ? AND rating > 0", maybe_user['id']))

    slim(:"/albumlist", locals:{user_hash:$user, logged_in:$logged_in, user_albums:user_albums})
end