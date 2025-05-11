class Product < ApplicationRecord
    field :name, :string

    belongs_to :user
end