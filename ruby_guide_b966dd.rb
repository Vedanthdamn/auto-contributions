# Learning Objective: Understand how to use Ruby metaprogramming (specifically `define_method`)
# to create a Domain Specific Language (DSL) for defining HTTP routes in a basic router.
# This tutorial demonstrates how to dynamically create methods to build a flexible API
# that looks clean and intuitive, much like frameworks like Sinatra or Rails.

# The Router class will be responsible for storing our defined routes and
# dispatching requests to the appropriate block of code.
class Router
  # We define a constant for common HTTP methods. This makes our code cleaner
  # and easier to modify if we ever want to support more methods.
  # These are the methods we want to dynamically define on our Router instance.
  HTTP_METHODS = %i[get post put delete]

  # In the initializer, we set up our route storage.
  # @routes will be a hash where keys are HTTP methods (e.g., "GET", "POST")
  # and values are another hash mapping specific paths to their respective action blocks (Procs).
  # Example structure after defining some routes:
  # {
  #   "GET" => {
  #     "/"       => #<Proc:0x...>, # This is the block action for GET /
  #     "/about"  => #<Proc:0x...>  # This is the block action for GET /about
  #   },
  #   "POST" => {
  #     "/submit" => #<Proc:0x...>  # This is the block action for POST /submit
  #   }
  # }
  # The `Hash.new { |hash, key| hash[key] = {} }` syntax ensures that if we try
  # to access `@routes["GET"]` and it doesn't exist, it will automatically create
  # an empty hash for "GET" before returning it. This prevents `NoMethodError`
  # when we try to assign a path-block pair to it.
  def initialize
    @routes = Hash.new { |hash, key| hash[key] = {} }
  end

  # This is the core of our metaprogramming example.
  # Metaprogramming is writing code that writes code. Here, we're writing
  # code that defines new methods on the Router instance at runtime.
  # We iterate over each HTTP method name (e.g., :get, :post) from our constant.
  # For each method name, we use `define_method` to create a new instance method
  # on our Router class *dynamically*.

  # `define_method` takes two arguments:
  # 1. The name of the method to define (e.g., :get, :post).
  # 2. A block that will serve as the body of the new method.
  HTTP_METHODS.each do |method_name|
    define_method(method_name) do |path, &block|
      # Inside the dynamically defined method (e.g., when `router.get('/path') do ... end` is called):
      # `self` refers to the current Router instance.
      # `method_name.to_s.upcase` converts the symbol :get to the string "GET".
      # `path` is the route string argument (e.g., "/").
      # `&block` captures the block (the `do ... end` part) passed to the `get` method
      # and turns it into a Proc object.
      # We store this Proc object (our action block) in our @routes hash,
      # indexed by the HTTP method and the path.
      # This effectively "registers" the route and its associated action.
      puts "Registering #{method_name.to_s.upcase} #{path}" # Educational output: shows routes being added
      @routes[method_name.to_s.upcase][path] = block
    end
  end

  # The `dispatch` method is responsible for taking an incoming request (HTTP method + path)
  # and finding the corresponding action block to execute.
  # This simulates what a web server (or a framework like Rack) would do when it
  # receives an HTTP request from a client.
  def dispatch(http_method, path)
    # Convert the incoming method to an uppercase string (e.g., :get becomes "GET")
    # for consistent lookup with the keys in our @routes hash.
    normalized_method = http_method.to_s.upcase

    # Attempt to find the handler block for the given method and path.
    # `@routes[normalized_method]` will first get the hash of paths for that method
    # (e.g., `{"/" => block1, "/about" => block2}`).
    # Then `[path]` will look up the specific path within that hash.
    # If a path isn't found, it returns `nil`.
    handler = @routes[normalized_method][path]

    if handler
      # If a handler (the action block, which is a Proc) is found, execute it using `call`.
      # The block's return value (e.g., "Hello from home page!") is returned as the "response".
      puts "-> Matched route: #{normalized_method} #{path}" # Educational output
      handler.call # Execute the block
    else
      # If no matching route is found for the given method and path, return a 404 Not Found message.
      puts "-> No route matched: #{normalized_method} #{path}" # Educational output
      "404 Not Found"
    end
  end
end

# --- Example Usage ---

puts "\n--- Initializing Router and Defining Routes ---"

# Create an instance of our router.
router = Router.new

# Use our dynamically defined methods (`get`, `post`, `delete`) to register routes.
# Notice how clean and intuitive this syntax is, resembling actual web frameworks
# like Sinatra. This is the power of a well-designed DSL using metaprogramming.
router.get '/' do
  "Hello from the home page!"
end

router.get '/about' do
  "This is the about page, built with Ruby metaprogramming."
end

router.post '/submit' do
  "Data received successfully via POST!"
end

router.delete '/item/1' do
  "Item 1 deleted successfully."
end

# We can even define multiple routes for the same path but different HTTP methods.
# The router distinguishes them by both method AND path.
router.get '/status' do
  "Current status: All systems nominal (GET request)."
end

router.post '/status' do
  "Attempting to update status... (POST request)."
end

puts "\n--- Testing Router Dispatch ---"

# Simulate incoming HTTP requests and see how the router dispatches them.
# The `dispatch` method acts as our web server's request handler.

puts "\nDispatching GET /:"
puts router.dispatch(:get, '/') # Expected: "Hello from the home page!"

puts "\nDispatching GET /about:"
puts router.dispatch(:get, '/about') # Expected: "This is the about page..."

puts "\nDispatching POST /submit:"
puts router.dispatch(:post, '/submit') # Expected: "Data received successfully..."

puts "\nDispatching DELETE /item/1:"
puts router.dispatch(:delete, '/item/1') # Expected: "Item 1 deleted successfully."

puts "\nDispatching GET /status:"
puts router.dispatch(:get, '/status') # Expected: "Current status: All systems nominal (GET request)."

puts "\nDispatching POST /status:"
puts router.dispatch(:post, '/status') # Expected: "Attempting to update status... (POST request)."

puts "\nDispatching GET /contact (non-existent route):"
puts router.dispatch(:get, '/contact') # Expected: "404 Not Found"

puts "\nDispatching PUT / (non-existent method for this path):"
puts router.dispatch(:put, '/') # Expected: "404 Not Found"
# Although we defined a PUT method dynamically, we didn't register a route for PUT /.