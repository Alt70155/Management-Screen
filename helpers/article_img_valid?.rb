require 'sinatra/reloader'
helpers do
  def article_img_valid?(body, img_files)
    body_img_ct = body.scan(/!\[\S*\]\(\S*\)/).length
    ary = img_files.map { |img| !(img[:filename] !~ /.*\.(jpg|png|jpeg)\z/) }
    body_img_ct == img_files.length && img_files.length < 10 && ary.all?
  end
end
