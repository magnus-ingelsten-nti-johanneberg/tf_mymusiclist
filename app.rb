require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/flash'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'
require_relative './model.rb'

enable :sessions

include Model

# Stores login status and current user as global variables, runs before every route
#
# @param [Hash] $user Hash of current user data
# @param [Boolean] $logged_in Whether or not user is logged in
#
# @see Model#is_logged_in
before do
    $user = session[:current_user]
    $logged_in = is_logged_in($user)
end

# Displays landing page
#
get('/') do
    slim(:index, locals:{user_hash:$user, logged_in:$logged_in})
end

# Checks if user has admin role, if not it redirects to '/'
#
# @param [Hash] $user Hash of current user data
# @param [Boolean] $logged_in Whether or not user is logged in
before('/albums/new') do
    if !$logged_in
        flash[:notice] = "You need admin permissions for this."
        redirect('/')
    elsif $user['role'] != "admin"
        flash[:notice] = "You need admin permissions for this."
        redirect('/')
    end
end

# Displays a form to add a new album
#
get('/albums/new') do
    slim(:"albums/new", locals:{user_hash:$user, logged_in:$logged_in})
end

# Adds a new album and redirects to '/albums'
#
# @param [String] album_title The title of the album
# @param [String] artist_name The name of the artist
# @param [String] album_type The type of album (LP, EP or Single)
# @param [String] release_date The release date of the album
#
# @see Model#add_album_full
post('/albums') do
    album_title = params[:album_title]
    artist_name = params[:artist_name]
    album_type = params[:album_type]
    release_date = params[:release_date]
    add_album_full(album_title, artist_name, album_type, release_date)
    redirect('/albums')
end

# Displays a list of all albums
#
get('/albums') do
    slim(:"albums/index",locals:{album_hash:albums_hash, user_hash:$user, logged_in:$logged_in})
end

# Deletes a specific album from the database
#
# @param [Integer] album_id Id of the album in question
#
# @see Model#delete_album
post('/albums/:id/delete') do
    album_id = params[:id].to_i
    delete_album(album_id)
    redirect back
end

# Displays a form to edit an existing album
#
# @param [Integer] album_id Id of the album in question
# @param [Hash] album_hash Hash of data for the album in question
#
# @see Model#get_album_hash_by_id
get('/albums/:id/edit') do
    album_id = params[:id].to_i
    album_hash = get_album_hash_by_id(album_id)
    slim(:"albums/edit", locals:{id:album_id, album_hash:album_hash, user_hash:$user, logged_in:$logged_in})
end

# Updates data of an existing album and redirects to '/albums'
#
# @param [String] album_title The title of the album
# @param [String] artist_name The name of the artist
# @param [String] album_type The type of album (LP, EP or Single)
# @param [String] release_date The release date of the album
# @param [Integer] old_album_id Id of the album being updated
#
# @see Model#update_album_full
post('/albums/:id/update') do
    album_title = params[:album_title]
    artist_name = params[:artist_name]
    album_type = params[:album_type]
    release_date = params[:release_date]
    old_album_id = (params[:id]).to_i
    update_album_full(album_title, artist_name, album_type, release_date, old_album_id)
    redirect('/albums')
end

# Displays a register form
#
get('/register') do
    slim(:"/register", locals:{user_hash:$user, logged_in:$logged_in})
end

# Attempts to register a user, if successful redirects to '/'
#
# @param [String] username Username entered into register form
# @param [String] password Password entered into register form
# @param [String] password_confirm Password confirmation entered into register form
#
# @see Model#username_empty
# @see Model#register_user
post('/users/new') do
    username = params[:username]
    password = params[:password]
    password_confirm = params[:password_confirm]
    if password == password_confirm && username_empty(username)
        register_user(username, password)
        redirect('/')
    else
        flash[:notice] = "Unmatching passwords."
        redirect back
    end
end

# Displays a login form
#
get('/login') do
    slim(:"/login", locals:{user_hash:$user, logged_in:$logged_in})
end

recent_logins = {}

# Attempts login and updates session
#
# @param [String] username Username entered into login form
# @param [String] password Password entered into login form
# @param [Hash] recent_logins Hash of latest login times per IP address
#
# @see Model#login_is_valid
# @see Model#select_user_hash
post('/login') do
    username = params[:username]
    password = params[:password]
    if (Time.now).to_i - (recent_logins[request.ip]).to_i < 5
        flash[:notice] = "Too many login attempts. Please wait a little."
        recent_logins[request.ip] = (Time.now).to_i
        redirect back
    else
        recent_logins[request.ip] = (Time.now).to_i
    end
    
    if login_is_valid(username, password)
        session[:current_user] = select_user_hash(username)
        redirect('/')
    else
        flash[:notice] = "Incorrect password or username."
        redirect back
    end
end

# Clears the session and redirects to '/'
#
get('/logout') do
    session.clear
    redirect('/')
end

# Displays a users profile page
#
# @param [String] profile_name Username of the profile specified in the route
# @param [Hash] maybe_user Hash of the user specified in the route
# @param [Hash] user_albums Hash of the albums a user has a relation to
#
# @see Model#select_user_hash
# @see Model#get_user_albums_by_user_id
get('/profile/:profile_username') do
    profile_name = params[:profile_username]
    maybe_user = select_user_hash(profile_name)

    if maybe_user != nil
        user_albums = get_user_albums_by_user_id(maybe_user['id'])
        slim(:"/profile", locals:{user_hash:$user, logged_in:$logged_in, profile_user:maybe_user, user_albums:user_albums})
    else
        slim(:"/error", locals:{user_hash:$user, logged_in:$logged_in, profile_user:maybe_user})
    end
end

# Displays a single album
#
# @param [Integer] album_id Id of the album in question
# @param [Hash] maybe_album Hash of all data relating to the album
# @param [Integer] favorites Number of favorites the album has
# @param [Float] average_rating The average rating of the album
#
# @see Model#get_all_album_data_by_id
# @see Model#user_album_relations_exist
# @see Model#number_of_favorites_by_id
# @see Model#average_rating_by_id
get('/album/:id/:title') do
    album_id = params[:id].to_i
    maybe_album = get_all_album_data_by_id(album_id)
    if user_album_relations_exist(album_id)
        favorites = number_of_favorites_by_id(album_id)
        average_rating = average_rating_by_id(album_id)
    else
        favorites = 0
        average_rating = 0
    end
    if maybe_album != nil
        slim(:"/albums/show", locals:{user_hash:$user, logged_in:$logged_in, page_album_hash:maybe_album, favorites:favorites, score:average_rating.round(2), album_id:album_id})
    else
        slim(:"/error", locals:{user_hash:$user, logged_in:$logged_in})
    end
end

# Updates the current users rating of an album
#
# @param [Integer] album_id Id of the album
# @param [Integer] rating What the user scored the album
# @param [Boolean] no_user_rating Whether or not the user has rated the album
#
# @see Model#user_doesnt_have_rating
# @see Model#insert_album_rating
# @see Model#update_album_rating
post('/album/:id/rating/update') do
    album_id = params[:id].to_i
    rating = params[:album_score].to_i
    no_user_rating = user_doesnt_have_rating($user['id'], album_id)
    if no_user_rating && rating != 0
        insert_album_rating(rating, $user['id'], album_id)
    else
        update_album_rating(rating, $user['id'], album_id)
    end
    redirect back
end

# Updates the current users favorite status for an album
#
# @param [Integer] album_id Id of the album
# @param [String] favorite_toggle What button the user pressed to toggle the favorite status
#
# @see Model#update_favorite_value
post('/album/:id/favorite/update') do
    album_id = params[:id].to_i
    favorite_toggle = params[:favorite_toggle]

    if favorite_toggle == "remove from favorites"
        update_favorite_value(0, $user['id'], album_id)
    elsif favorite_toggle == "add to favorites"
        update_favorite_value(1, $user['id'], album_id)
    end
    redirect back
end

# Displays the unique album list of a user
#
# @param [String] list_username Username specified in the route
# @param [Hash] maybe_user Hash of the user specified in the route
# @param [Hash] user_albums Hash of the albums a user has a relation to
#
# @see Model#select_user_hash
# @see Model#get_user_albums
get('/albumlist/:username') do
    list_username = params[:username]

    maybe_user = select_user_hash(list_username)

    if maybe_user != nil
        user_albums = get_user_albums(maybe_user['id'])
        slim(:"/albumlist", locals:{user_hash:$user, logged_in:$logged_in, user_albums:user_albums})
    else
        slim(:"/error", locals:{user_hash:$user, logged_in:$logged_in})
    end
end