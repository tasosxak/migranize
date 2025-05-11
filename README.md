# Migranize

Migranize is a Ruby gem that automatically generates Rails migration files by analyzing changes in your models, similar to Django's migration system.


## Features

* Automatically detect changes in your Rails models
* Generate migration files based on model changes
* Simple CLI commands for generating migrations
* Seamless integration with Rails' migration system
* Inspired by Django's migration workflow

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'migranize'
```

And then execute:

```sh
bundle install
```

## Setup

Initialize Migranize in your Rails project:

```sh
bundle exec migranize init
```

This will create a configuration file at `config/migranize.rb`.

## Usage

### Define your models

Define your models using the field system provided by Migranize:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  field :name, :string
  field :email, :string
  field :age, :integer
  field :active, :boolean, default: true
  
  has_many :posts
end

# app/models/post.rb
class Post < ApplicationRecord
  field :title, :string
  field :content, :text
  field :published_at, :datetime
  
  belongs_to :user
end
```

### Generate migrations

After defining or changing your models, generate migrations with:

```sh
bundle exec migranize make_migrations
```

This will analyze your models, detect changes, and create migration files in your `db/migrate` directory.

### Run migrations

Once the migrations are generated, run them using Rails' standard command:

```bash
rails db:migrate
```

### Configuration

ou can customize Migranize's behavior in the configuration file (`config/migranize.rb`):

```ruby
Migranize.configure do |config|
  # Namespaces to ignore when detecting model changes
  config.ignore_namespaces = []
  
  # Tables to ignore when generating migrations
  config.ignore_tables = []
  
  # Directory where migration files are stored
  config.migrations_dir = "db/migrate"
  
  # Directory where model files are stored
  config.models_dir = "app/models"
end
```

### Field Types

Migranize supports all standard `ActiveRecord` column types:

```ruby
:string
:text
:integer
:float
:decimal
:datetime
:time
:date
:binary
:boolean
:json
:jsonb (PostgreSQL only)
:uuid (PostgreSQL only)
```

### Field Options
You can specify various options when defining fields:

```ruby
field :name, :string, null: false
field :price, :decimal, precision: 10, scale: 2
field :status, :string, default: "pending"
field :metadata, :json, null: true
```

### Examples

#### Basic Model Definition

```ruby
class Product < ApplicationRecord
  field :name, :string
  field :description, :text
  field :price, :decimal, precision: 10, scale: 2
  field :in_stock, :boolean, default: true
  field :released_at, :datetime
end
```

#### Adding or Changing Fields

When you add or change fields in your model:

```ruby
class Product < ApplicationRecord
  field :name, :string
  field :description, :text
  field :price, :decimal, precision: 10, scale: 2
  field :in_stock, :boolean, default: true
  field :released_at, :datetime
  field :category, :string  # New field
  field :tags, :json  # New field
end
```

Running `migranize make_migrations` will generate a migration that adds these new fields to your table.

# License
The gem is available as open source under the terms of the MIT License.