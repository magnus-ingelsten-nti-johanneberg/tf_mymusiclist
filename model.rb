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