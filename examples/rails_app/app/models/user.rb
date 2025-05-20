class User < ApplicationRecord
    field :first_name, :string

    has_one :product
end