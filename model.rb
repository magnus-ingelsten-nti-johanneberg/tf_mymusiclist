require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/flash'
require 'slim'
require 'sqlite3'
require 'bcrypt'
require 'date'

# Contains all helper functions for the application
#
module Model

    # Stores a database as a hash in a variable
    # 
    # @param [String] path The path to the database file
    #
    # @return [Hash] containing the entire database
    def db_connect(path)
        db = SQLite3::Database.new(path)
        db.results_as_hash = true
        return db
    end


    # Returns whether or not a user is currently logged in
    #
    # @param [Hash] user The user hash stored in the session
    #
    # @return [Boolean] if user is logged in or not
    def is_logged_in(user)
        return user != nil
    end

    # Returns whether or not a user exists
    #
    # @param [Hash] user The user hash stored in the session
    #
    # @return [Boolean] if user exists
    def user_exists(user)
        return user != nil
    end

    # Creates a new user
    #
    # @param [String] username Username entered in register form
    # @param [String] password Password entered in register form
    def register_user(username, password)
        db = db_connect("db/mml_db.db")
        password_digest = BCrypt::Password.create(password)
        current_date = (Time.now).strftime("%Y-%m-%d")
        db.execute("INSERT INTO user (role, username, password_digest, register_date) VALUES (?, ?, ?, ?)", "plebian", username, password_digest, current_date)
    end

    # Returns whether or not a password matches with a stored password digest
    #
    # @param [String] input_password Input password
    # @param [String] user_password_digest Stored password digest for user
    #
    # @return [Boolean] whether the password matches the stored digest
    def password_check(input_password, user_password_digest)
        x = BCrypt::Password.new(user_password_digest) == input_password
        return x
    end

    #helpers
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


    # Finds id of an album by its title
    #
    # @param [String] title The title of the album
    # 
    # @return [Integer] the id of the album
    # @return [nil] if not found
    def get_album_id(title)
        db = db_connect("db/mml_db.db")
        id = db.execute("SELECT id FROM album WHERE title = ?", title)[0]
        if id != nil
            return id['id']
        else
            return nil
        end
    end

    # Finds id of an artist by their name
    #
    # @param [String] name The name of the artist
    # 
    # @return [Integer] the id of the artist
    # @return [nil] if not found
    def get_artist_id(name)
        db = db_connect("db/mml_db.db")
        id = db.execute("SELECT id FROM artist WHERE name = ?", name)[0]
        if id != nil
            return id['id']
        else
            return nil
        end
    end

    # Returns whether an artist and an album have a relation
    #
    # @param [Integer] artist_id the id of the artist
    # @param [Integer] album_id the id of the album
    #
    # @return [Boolean] whether an album and an artist have a relation
    def no_artist_album_relation(artist_id, album_id)
        db = db_connect("db/mml_db.db")
        is_empty = db.execute("SELECT id FROM artist_album_rel WHERE artist_id = ? AND album_id = ?", artist_id, album_id).empty?
        return is_empty
    end

    # Inserts a new album into the album table
    #
    # @param [String] title The title of the album
    # @param [String] type The type of album (LP, EP or Single)
    # @param [String] date The release date of the album
    def insert_album(title, type, date)
        db = db_connect("db/mml_db.db")
        db.execute("INSERT INTO album (title, type, release_date) VALUES (?, ?, ?)", title, type, date)
    end

    # Inserts a new artist into the artist table
    #
    # @param [String] name The name of the artist
    def insert_artist(name)
        db = db_connect("db/mml_db.db")
        db.execute("INSERT INTO artist (name) VALUES (?)", name)
    end

    # Inserts a new artist-album relation into the artist_album_rel table
    #
    # @param [Integer] artist_id the id of the artist
    # @param [Integer] album_id the id of the album
    def insert_artist_album_relation(artist_id, album_id)
        db = db_connect("db/mml_db.db")
        db.execute("INSERT INTO artist_album_rel (artist_id, album_id) VALUES (?, ?)", artist_id, album_id)
    end

    # Deletes an album from all tables with album data
    #
    # @param [Integer] album_id the id of the album
    def delete_album(album_id)
        db = db_connect("db/mml_db.db")
        db.execute("DELETE FROM album WHERE id = ?", album_id)
        db.execute("DELETE FROM artist_album_rel WHERE album_id = ?", album_id)
        db.execute("DELETE FROM user_album_rel WHERE album_id = ?", album_id)
    end

    # Updates an existing album in the album table
    #
    # @param [String] title The title of the album
    # @param [String] type The type of album (LP, EP or Single)
    # @param [String] date The release date of the album
    # @param [Integer] id the id of the album
    def update_album(title, type, date, id)
        db = db_connect("db/mml_db.db")
        db.execute("UPDATE album SET title = ?, type = ?, release_date = ? WHERE id = ?", title, type, date, id)
    end

    # Updates album data in all tables containing album data 
    #
    # @param [String] album_title The title of the album
    # @param [String] artist_name The name of the artist
    # @param [String] album_type The type of album (LP, EP or Single)
    # @param [String] release_date The release date of the album
    # @param [Integer] old_album_id the id of the album
    #
    # @see Model#get_album_id
    # @see Model#get_artist_id
    # @see Model#no_artist_album_relation
    # @see Model#update_album
    # @see Model#insert_artist

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

    # Inserts a new album into all tables containing album data 
    #
    # @param [String] album_title The title of the album
    # @param [String] artist_name The name of the artist
    # @param [String] album_type The type of album (LP, EP or Single)
    # @param [String] release_date The release date of the album
    #
    # @see Model#get_album_id
    # @see Model#get_artist_id
    # @see Model#no_artist_album_relation
    # @see Model#insert_album
    # @see Model#insert_artist
    # @see Model#insert_artist_album_relation
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

    # Returns a hash with all album data of an album
    #
    # @param [Integer] album_id the id of the album
    #
    # @return [Hash] containing album data of an album
    def get_album_hash_by_id(album_id)
        db = db_connect("db/mml_db.db")

        hash = db.execute("SELECT title, type, release_date, name, artist_id, album_id, artist_album_rel.id FROM album INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist.id = artist_album_rel.artist_id WHERE album_id = ?", album_id)[0]

        return hash
    end

    # Returns hash of user data
    #
    # @param [String] username Username of the user
    #
    # @return [Hash] containing all of a user's data
    def select_user_hash(username)
        db = db_connect("db/mml_db.db")
        selected_user = db.execute("SELECT * FROM user WHERE username = ?", username)[0]
        return selected_user
    end

    # Returns whether a username and password match
    #
    # @param [String] username Username entered into login form
    # @param [String] password Password entered into login form
    #
    # @return [Boolean] whether the username and password match
    #
    # @see Model#user_exists
    # @see Model#password_check
    def login_is_valid(username, password) #följer denna MVC-modellen?

        selected_user = select_user_hash(username)

        if user_exists(selected_user)
            user_password_digest = selected_user["password_digest"]
            if password_check(password, user_password_digest)
                login_valid = true
            else
                login_valid = false
            end
        else
            login_valid = false
        end
        return login_valid
    end

    # Returns all albums data for a specific user
    #
    # @param [Integer] user_id The id of the user
    #
    # @return [Hash] containing all albums and their data a user has a relation to
    def get_user_albums_by_user_id(user_id)
        db = db_connect("db/mml_db.db")

        return db.execute("SELECT title, type, release_date, role, username, user_id, album_id, is_favorite, rating, user_album_rel.id FROM album INNER JOIN user_album_rel ON album.id = user_album_rel.album_id INNER JOIN user ON user.id = user_album_rel.user_id WHERE user_id = ?", user_id)
    end

    # Returns all data of a specific album
    #
    # @param [Integer] album_id The id of the album
    #
    # @return [Hash] containing all album data of the album
    def get_all_album_data_by_id(album_id)
        db = db_connect("db/mml_db.db")

        return (db.execute("SELECT title, type, release_date, name, role, username, user.id AS user_id, album.id AS album_id, is_favorite, rating, user_album_rel.id AS rel_id FROM album LEFT JOIN user_album_rel ON album.id = user_album_rel.album_id LEFT JOIN user ON user.id = user_album_rel.user_id LEFT JOIN artist_album_rel ON album.id = artist_album_rel.album_id LEFT JOIN artist ON artist_album_rel.artist_id = artist.id WHERE artist_album_rel.album_id = ?", album_id))[0]
    end

    # Returns number of favorites an album has
    #
    # @param [Integer] album_id The id of the album
    #
    # @return [Integer] The total number of favorites the album has 
    def number_of_favorites_by_id(album_id)
        db = db_connect("db/mml_db.db")
        favs = (db.execute("SELECT COUNT(is_favorite) AS number_of_favorites FROM user_album_rel WHERE is_favorite == 1 AND album_id = ?", album_id)[0])['number_of_favorites']
        if favs == nil
            favs = 0
        end
        return favs
    end

    # Returns average rating an album has
    #
    # @param [Integer] album_id The id of the album
    #
    # @return [Float] The average score the album has 
    def average_rating_by_id(album_id)
        db = db_connect("db/mml_db.db")
        average_rating = (db.execute("SELECT AVG(rating) AS avg FROM user_album_rel WHERE rating >= 1 AND album_id = ?", album_id)[0])['avg']
        if average_rating == nil
            average_rating = 0
        end
        return average_rating
    end

    # Returns whether any user has favorited or rated an album
    #
    # @param [Integer] album_id The id of the album
    #
    # @return [Boolean] whether any user has favorited or rated an album
    def user_album_relations_exist(album_id)
        db = db_connect("db/mml_db.db")
        user_album_relations = db.execute("SELECT * FROM user_album_rel WHERE album_id = ?", album_id)[0]
        return user_album_relations != nil
    end

    # Returns whether a user hasn't rated an album
    #
    # @param [Integer] user_id The id of the user
    # @param [Integer] album_id The id of the album
    #
    # @return [Boolean] whether the user hasn't rated the album
    def user_doesnt_have_rating(user_id, album_id)
        db = db_connect("db/mml_db.db")

        user_no_rating = (db.execute("SELECT id FROM user_album_rel WHERE user_id = ? AND album_id = ?", user_id, album_id)[0]).nil?
        return user_no_rating
    end


    # Inserts an album rating for a user
    #
    # @param [Integer] rating The rating set by the user
    # @param [Integer] user_id The id of the user
    # @param [Integer] album_id The id of the album
    def insert_album_rating(rating, user_id, album_id)
        db = db_connect("db/mml_db.db")
        db.execute("INSERT INTO user_album_rel (rating, user_id, album_id) VALUES (?, ?, ?)", rating, user_id, album_id)
    end

    # Updates an existing album rating for a user
    #
    # @param [Integer] rating The rating set by the user
    # @param [Integer] user_id The id of the user
    # @param [Integer] album_id The id of the album
    def update_album_rating(rating, user_id, album_id)
        db = db_connect("db/mml_db.db")
        db.execute("UPDATE user_album_rel SET rating = ? WHERE user_id = ? AND album_id = ?", rating, user_id, album_id)
    end

    # Updates an albums favorite status for a user
    #
    # @param [Integer] value 1 or 0, whether to be favorited or not
    # @param [Integer] user_id The id of the user
    # @param [Integer] album_id The id of the album
    def update_favorite_value(value, user_id, album_id)
        db = db_connect("db/mml_db.db")
        db.execute("UPDATE user_album_rel SET is_favorite = ? WHERE user_id = ? AND album_id = ?", value, user_id, album_id)
    end

    # Returns a hash of all albums data, including ratings and favorite status, for a user
    #
    # @param [Integer] user_id The id of the user
    #
    # @return [Hash] containing all data for every album a user has favorited or rated
    def get_user_albums(user_id)
        db = db_connect("db/mml_db.db")
        user_albums = (db.execute("SELECT title, type, release_date, name, role, username, user_id, user_album_rel.album_id, is_favorite, rating, user_album_rel.id FROM album INNER JOIN user_album_rel ON album.id = user_album_rel.album_id INNER JOIN user ON user.id = user_album_rel.user_id INNER JOIN artist_album_rel ON album.id = artist_album_rel.album_id INNER JOIN artist ON artist_album_rel.artist_id = artist.id WHERE user_id = ? AND rating > 0", user_id))
        return user_albums
    end

    # Returns whether a username is not already registered
    #
    # @param [String] username The entered username
    #
    # @return [Boolean] whether the username is not already registered
    def username_empty(username)
        db = db_connect("db/mml_db.db")
        is_empty = (db.execute("SELECT username FROM user WHERE username = ?", username)).empty?
        return is_empty
    end

end