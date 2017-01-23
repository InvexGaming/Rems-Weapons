-- RW database
-- Entry exists for each weapon per steam ID

CREATE TABLE IF NOT EXISTS rw (
  steamid VARCHAR(32) NOT NULL,
  weaponname VARCHAR(32) NOT NULL,
  paint INT NOT NULL,
  wear FLOAT NOT NULL,
  seed INT NOT NULL,
  stattrak INT NOT NULL,
  stattrakLock BOOLEAN NOT NULL,
  entityQuality INT NOT NULL,
  nametagText VARCHAR(255) NOT NULL,
  nametagColourCode VARCHAR(10) NOT NULL,
  nametagFontSize INT NOT NULL,
  PRIMARY KEY  (steamid, weaponname)
)