# importing required libraries
import mysql.connector

dataBase = mysql.connector.connect(
  host ="localhost",
  user ="root",
  passwd ="StrongPassword"
)

# preparing a cursor object
cursorObject = dataBase.cursor()

# creating database
cursorObject.execute("CREATE DATABASE phplist")
cursorObject.execute("GRANT ALL PRIVILEGES ON phplist.* to 'phplist'@'localhost' IDENTIFIED BY 'StrongPassword'")
cursorObject.execute("FLUSH PRIVILEGES")
