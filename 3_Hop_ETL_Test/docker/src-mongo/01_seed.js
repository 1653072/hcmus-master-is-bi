// Movies, Genres, Persons — messy JSON documents for daily JSONL pull
//
// movielens_auth  — stores hop_reader credentials (auth database)
// movielens_data  — stores collections: movies, genres, persons (data database)

db = db.getSiblingDB('movielens_auth');

db.createUser({
  user: 'hop_reader',
  pwd: 'hop_reader',
  roles: [{ role: 'read', db: 'movielens_data' }],
});

db = db.getSiblingDB('movielens_data');

db.movies.insertMany([
  {
    movie_id: 1,
    title: 'Toy Story',
    release_year: 1995,
    genres: ['Animation', "Children's", 'Comedy'],
    runtime_minutes: 81,
    tmdb_id: 862,
    updatedAt: ISODate('2024-06-01T00:00:00Z'),
  },
  {
    movie_id: '2',
    title: 'Jumanji',
    release_year: 1995,
    genres: 'Adventure|Children|Fantasy',
    runtime_minutes: 104,
    updatedAt: ISODate('2024-06-02T00:00:00Z'),
  },
  {
    movie_id: 3,
    title: 'Grumpier Old Men',
    release_year: 1995,
    genres: ['Comedy', 'Romance'],
    runtime_minutes: null,
    updatedAt: ISODate('2024-06-03T00:00:00Z'),
  },
  {
    movie_id: 4,
    title: 'Waiting to Exhale',
    release_year: 1995,
    genres: ['Comedy', 'Drama'],
    runtime_minutes: 127,
    updatedAt: ISODate('2024-06-04T00:00:00Z'),
  },
  {
    movie_id: 5,
    title: 'Father of the Bride Part II',
    release_year: 1995,
    genres: ['Comedy'],
    updatedAt: ISODate('2024-06-05T00:00:00Z'),
  },
  {
    movie_id: 1,
    title: 'Toy Story (1995)',
    release_year: '1995',
    genres: ['Animation', 'Comedy'],
    runtime_minutes: 81,
    updatedAt: ISODate('2024-06-06T00:00:00Z'),
  },
]);

db.genres.insertMany([
  { genre_id: 1, name: 'Animation', updatedAt: ISODate('2024-06-01T00:00:00Z') },
  { genre_id: 2, name: "Children's", updatedAt: ISODate('2024-06-01T00:00:00Z') },
  { genre_id: 3, name: 'Children', updatedAt: ISODate('2024-06-02T00:00:00Z') },
  { genre_id: 4, name: 'Comedy', updatedAt: ISODate('2024-06-01T00:00:00Z') },
  { genre_id: 5, name: 'Adventure', updatedAt: ISODate('2024-06-02T00:00:00Z') },
  { genre_id: 6, name: 'Drama', updatedAt: ISODate('2024-06-03T00:00:00Z') },
]);

db.persons.insertMany([
  {
    person_id: 101,
    name: 'Tom Hanks',
    role: 'Actor',
    birth_year: 1956,
    movie_ids: [1, 4],
    updatedAt: ISODate('2024-06-01T00:00:00Z'),
  },
  {
    person_id: 102,
    name: 'Tim Allen',
    role: 'Actor',
    birth_year: 1953,
    movie_ids: [1],
    updatedAt: ISODate('2024-06-02T00:00:00Z'),
  },
  {
    person_id: 103,
    name: 'Robin Williams',
    role: 'Actor',
    birth_year: null,
    movie_ids: ['2'],
    updatedAt: ISODate('2024-06-03T00:00:00Z'),
  },
  {
    person_id: 104,
    name: 'Tom Hanks',
    role: 'Producer',
    birth_year: 1956,
    movie_ids: [4],
    updatedAt: ISODate('2024-06-04T00:00:00Z'),
  },
  {
    person_id: 105,
    name: 'Unknown Cast',
    role: null,
    movie_ids: [5],
    updatedAt: ISODate('2024-06-05T00:00:00Z'),
  },
]);
