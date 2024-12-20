// Modal functionality
document.addEventListener('DOMContentLoaded', function() {
    const modal = document.getElementById('aboutMeModal');
    const btn = document.getElementById('aboutMeBtn');
    const span = document.getElementsByClassName('close')[0];
    const startButton = document.querySelector('.modal-content .button');

    // Show modal automatically on page load
    setTimeout(() => {
        modal.style.display = "block";
    }, 1000);

    // Button click opens modal
    btn.onclick = function() {
        modal.style.display = "block";
    }

    // Close button closes modal
    span.onclick = function() {
        modal.style.display = "none";
    }

    // Get Started button closes modal
    startButton.onclick = function() {
        modal.style.display = "none";
    }

    // Click outside modal closes it
    window.onclick = function(event) {
        if (event.target == modal) {
            modal.style.display = "none";
        }
    }
    
    // Remove sidebar-related functionality
    // ...rest of existing code...
});

// Remove toggleSidebar and startTutorial functions
// ...rest of existing code...

function scrollToStep(stepElement) {
    const offset = 50; // Offset from the top of the viewport
    const elementPosition = stepElement.getBoundingClientRect().top;
    const offsetPosition = elementPosition + window.pageYOffset - offset;

    window.scrollTo({
        top: offsetPosition,
        behavior: 'smooth'
    });
}

function revealStep(stepNumber) {
    // Hide all path containers first
    document.querySelectorAll('.path-container').forEach(container => {
        container.classList.add('hidden');
        container.classList.remove('visible');
    });

    // Determine which path to show (steps 6-9 are beginner path)
    const isBeginnerPath = stepNumber >= 6;
    const pathContainer = document.getElementById(isBeginnerPath ? 'beginner-path' : 'advanced-path');
    pathContainer.classList.remove('hidden');
    pathContainer.classList.add('visible');

    // Hide all steps within the current path
    pathContainer.querySelectorAll('.step').forEach(step => {
        step.classList.add('hidden');
    });

    // Show the requested step immediately
    const stepToShow = document.getElementById(`step${stepNumber}`);
    if (stepToShow) {
        stepToShow.classList.remove('hidden');
        stepToShow.classList.add('visible');
        
        // Ensure step content is visible
        const stepContent = stepToShow.querySelector('.step-content');
        if (stepContent) {
            stepContent.classList.add('visible');
        }
        
        scrollToStep(stepToShow);
    }
}

function copyCode(buttonElement) {
    const codeBlock = buttonElement.parentElement.querySelector('pre');
    const text = codeBlock.textContent;
    
    navigator.clipboard.writeText(text).then(() => {
        const originalText = buttonElement.textContent;
        buttonElement.textContent = 'Copied!';
        setTimeout(() => {
            buttonElement.textContent = originalText;
        }, 2000);
    });
}

async function loadTerraformConfig() {
    try {
        const response = await fetch('main.tf');
        const text = await response.text();
        const codeBlock = document.querySelector('#terraform-config');
        if (codeBlock) {
            codeBlock.textContent = text;
        }
    } catch (error) {
        console.error('Error loading Terraform config:', error);
    }
}

// Call this when the page loads
document.addEventListener('DOMContentLoaded', () => {
    loadTerraformConfig();
    
    // Add sidebar-expanded class to container on page load
    document.querySelector('.container').classList.add('sidebar-expanded');
    
    // Add new carousel functionality
    let currentIndex = 0;
    const track = document.querySelector('.carousel-track');
    const cards = document.querySelectorAll('.path-card');
    const cardWidth = cards[0].offsetWidth + 32; // Include gap

    // Update carousel functionality
    function updateCarousel() {
        const containerWidth = document.querySelector('.carousel-container').offsetWidth;
        const cardWidth = cards[0].offsetWidth + 32; // Include gap
        const offset = (containerWidth / 2) - (cardWidth / 2);
        const newTransform = -currentIndex * cardWidth + offset;
        
        track.style.transform = `translateX(${newTransform}px)`;
        
        // Update active states
        cards.forEach((card, index) => {
            const isActive = index === currentIndex;
            card.classList.toggle('active', isActive);
            
            // Optional: Also add a "near-active" class for cards adjacent to the active one
            const isNearActive = Math.abs(index - currentIndex) === 1;
            card.classList.toggle('near-active', isNearActive);
        });
    }

    // Add automatic rotation if desired
    let autoplayInterval;

    function startAutoplay() {
        autoplayInterval = setInterval(() => {
            currentIndex = (currentIndex + 1) % cards.length;
            updateCarousel();
        }, 5000); // Change slides every 5 seconds
    }

    function stopAutoplay() {
        clearInterval(autoplayInterval);
    }

    // Start autoplay and handle mouse interactions
    startAutoplay();

    track.addEventListener('mouseenter', stopAutoplay);
    track.addEventListener('mouseleave', startAutoplay);

    document.querySelector('.next').addEventListener('click', () => {
        currentIndex = (currentIndex + 1) % cards.length;
        updateCarousel();
    });

    document.querySelector('.prev').addEventListener('click', () => {
        currentIndex = (currentIndex - 1 + cards.length) % cards.length;
        updateCarousel();
    });

    // Add window resize handler
    window.addEventListener('resize', () => {
        updateCarousel();
    });

    // Add search functionality
    const searchInput = document.getElementById('projectSearch');
    searchInput.addEventListener('input', (e) => {
        const searchTerm = e.target.value.toLowerCase();
        cards.forEach(card => {
            const text = card.textContent.toLowerCase();
            const shouldShow = text.includes(searchTerm);
            card.style.display = shouldShow ? 'block' : 'none';
        });
    });

    // Initialize carousel
    updateCarousel();

    // Add touch support for mobile
    let touchStartX = 0;
    let touchEndX = 0;

    track.addEventListener('touchstart', e => {
        touchStartX = e.changedTouches[0].screenX;
    });

    track.addEventListener('touchend', e => {
        touchEndX = e.changedTouches[0].screenX;
        if (touchStartX - touchEndX > 50) {
            // Swipe left
            currentIndex = Math.min(currentIndex + 1, cards.length - 1);
            updateCarousel();
        } else if (touchEndX - touchStartX > 50) {
            // Swipe right
            currentIndex = Math.max(currentIndex - 1, 0);
            updateCarousel();
        }
    });
});
