require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/flash'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'

def db_connect(path)
    db = SQLite3::Database.new(path)
    db.results_as_hash = true
    return db
end

def is_logged_in(user)
    return user != nil
end

def user_exists(user)
    return user != nil
end

def register_user(username, password)
    db = db_connect("db/mml_db.db")
    password_digest = BCrypt::Password.create(password)
    current_date = (Time.now).strftime("%Y-%m-%d")
    db.execute("INSERT INTO user (role, username, password_digest, register_date) VALUES (?, ?, ?, ?)", "plebian", username, password_digest, current_date)
end

def password_check(input_password, user_password_digest)
    x = BCrypt::Password.new(user_password_digest) == input_password
    return x
end


#HELPERS

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
    def specific_user_album_rel_hash(album_id, user_id)
        if $logged_in
            db = db_connect("db/mml_db.db")
            result = db.execute("SELECT title, user_id, album_id, is_favorite, rating, user_album_rel.id AS rel_id FROM album INNER JOIN user_album_rel ON album.id = user_album_rel.album_id INNER JOIN user ON user.id = user_album_rel.user_id WHERE album_id = ? AND user_id = ?", album_id, user_id)[0]
        end
        return result
    end
end



#SQL SKIT
def get_album_id(title)
    db = db_connect("db/mml_db.db")
    id = db.execute("SELECT id FROM album WHERE title = ?", title)[0]
    if id != nil
        return id['id']
    else
        return nil
    end
end

def get_artist_id(name)
    db = db_connect("db/mml_db.db")
    id = db.execute("SELECT id FROM artist WHERE name = ?", name)[0]
    if id != nil
        return id['id']
    else
        return nil
    end
end

def no_artist_album_relation(artist_id, album_id)
    db = db_connect("db/mml_db.db")
    is_empty = db.execute("SELECT id FROM artist_album_rel WHERE artist_id = ? AND album_id = ?", artist_id, album_id).empty?
    return is_empty
end

def insert_album(title, type, date)
    db = db_connect("db/mml_db.db")
    db.execute("INSERT INTO album (title, type, release_date) VALUES (?, ?, ?)", title, type, date)
end

def insert_artist(name)
    db = db_connect("db/mml_db.db")
    db.execute("INSERT INTO artist (name) VALUES (?)", name)
end

def insert_artist_album_relation(artist_id, album_id)
    db = db_connect("db/mml_db.db")
    db.execute("INSERT INTO artist_album_rel (artist_id, album_id) VALUES (?, ?)", artist_id, album_id)
end

def delete_album(album_id)
    db = db_connect("db/mml_db.db")
    db.execute("DELETE FROM album WHERE id = ?", album_id)
    db.execute("DELETE FROM artist_album_rel WHERE album_id = ?", album_id)
    db.execute("DELETE FROM user_album_rel WHERE album_id = ?", album_id)
end

def update_album(title, type, date, id)
    db = db_connect("db/mml_db.db")
    db.execute("UPDATE album SET title = ?, type = ?, release_date = ? WHERE id = ?", title, type, date, id)
end

def update_album_full(album_title, artist_name, album_type, release_date, old_album_id)
    db = db_connect("db/mml_db.db")

    input_album_id = get_album_id(album_title) #id för albumet som heter det som skrivits i formuläret, om det finns
    input_artist_id = get_artist_id(artist_name)  #id för artisten som heter det som skrivits i formuläret, om det finns

    if no_artist_album_relation(input_artist_id, input_album_id)

        update_album(album_title, album_type, release_date, old_album_id)

        if input_artist_id == nil
            insert_artist(artist_name)
        end

        new_artist_id = get_artist_id(artist_name)
        db.execute("UPDATE artist_album_rel SET artist_id = ? WHERE album_id = ?", new_artist_id, old_album_id) #lägg in i relationstabell
    else
        flash[:notice] = "This album already exists :)"
    end
end

def add_album_full(album_title, artist_name, album_type, release_date)
    db = db_connect("db/mml_db.db")

    input_album_id = get_album_id(album_title) #id för albumet som heter det som skrivits i formuläret, om det finns
    input_artist_id = get_artist_id(artist_name)  #id för artisten som heter det som skrivits i formuläret, om det finns
    if no_artist_album_relation(input_artist_id, input_album_id) #om kombon inte finns

        #lägg in albumets titel, typ och release date i album-tabellen
        insert_album(album_title, album_type, release_date)

        if input_artist_id == nil #om artisten inte finns -> lägg in artisten
            insert_artist(artist_name)
        end

        #artist och album finns nu.
        new_artist_id = get_artist_id(artist_name) #id för artisten som specifierats
        new_album_id = get_album_id(album_title) #id för albumet som specifierats

        insert_artist_album_relation(new_artist_id, new_album_id) #lägg in i relationstabellen id:n för album och artist
    else
        flash[:notice] = "This album already exists :)"
    end
end

def get_album_hash_by_id(album_id)
    db = db_connect("db/mml_db.db")

    hash = db.execute("SELECT title, type, release_date, name, artist_id, album_id, artist_album_rel.id FROM album INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist.id = artist_album_rel.artist_id WHERE album_id = ?", album_id)[0]

    return hash
end

def login_func(username, password) #följer denna MVC-modellen?
    db = db_connect("db/mml_db.db")

    selected_user = db.execute("SELECT * FROM user WHERE username = ?", username)[0]

    if user_exists(selected_user)
        user_password_digest = selected_user["password_digest"]
        if password_check(password, user_password_digest)
            session[:current_user] = selected_user #:current_user är hash
            redirect('/')
        else
            flash[:notice] = "Incorrect password."
            redirect back
        end
    else
        flash[:notice] = "Incorrect username."
        redirect back
    end
end

def get_user_by_name(name)
    db = db_connect("db/mml_db.db")

    return db.execute("SELECT * FROM user WHERE username = ?", name)[0]
end

def get_user_albums_by_user_id(user_id)
    db = db_connect("db/mml_db.db")

    return db.execute("SELECT title, type, release_date, role, username, user_id, album_id, is_favorite, rating, user_album_rel.id FROM album INNER JOIN user_album_rel ON album.id = user_album_rel.album_id INNER JOIN user ON user.id = user_album_rel.user_id WHERE user_id = ?", user_id)
end

def get_all_album_data_by_id(album_id)
    db = db_connect("db/mml_db.db")

    return (db.execute("SELECT title, type, release_date, name, role, username, user.id AS user_id, album.id AS album_id, is_favorite, rating, user_album_rel.id AS rel_id FROM album LEFT JOIN user_album_rel ON album.id = user_album_rel.album_id LEFT JOIN user ON user.id = user_album_rel.user_id LEFT JOIN artist_album_rel ON album.id = artist_album_rel.album_id LEFT JOIN artist ON artist_album_rel.artist_id = artist.id WHERE artist_album_rel.album_id = ?", album_id))[0]
end