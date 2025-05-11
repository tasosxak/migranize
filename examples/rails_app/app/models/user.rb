class User < ApplicationRecord
    field :first_name, :text

    has_one :product
end