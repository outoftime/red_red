class Post < RedRed::Object
  rattr_accessor :title
  rattr_accessor :blog
end

class Blog < RedRed::Object
  rattr_accessor :name
  rattr_accessor :subdomain
end
