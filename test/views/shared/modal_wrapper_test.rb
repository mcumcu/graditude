require "test_helper"

class SharedModalWrapperTest < ActionView::TestCase
  test "renders modal overlay, close button, and body content" do
    render inline: <<~ERB
      <%= render "shared/modal_wrapper", title: "Modal title" do %>
        Modal body content
      <% end %>
    ERB

    assert_select "div.fixed"
    assert_select "div.absolute"
    assert_select "button[onclick*='history.back()']", text: "✖︎"
    assert_match "Modal body content", rendered
  end

  test "renders close button with explicit close_path" do
    render inline: <<~ERB
      <%= render "shared/modal_wrapper", title: "Modal title", close_path: "/prev-page" do %>
        Modal body content
      <% end %>
    ERB

    assert_select "button[onclick=\"window.location='/prev-page'\"]", text: "✖︎"
  end
end
