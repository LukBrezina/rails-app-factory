import "@hotwired/turbo-rails"
import "controllers"

// Full page loads only: Turbo Drive's body swaps would re-run the terminal
// module script and leak a live tmux attach per navigation.
Turbo.session.drive = false
