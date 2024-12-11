// Update toggleSidebar function
function toggleSidebar() {
    const sidebar = document.getElementById('introSidebar');
    const container = document.querySelector('.container');
    const menuIcon = document.getElementById('menuIcon');
    
    sidebar.classList.toggle('collapsed');
    container.classList.toggle('sidebar-expanded');
}

function startTutorial() {
    document.getElementById('introSidebar').classList.add('collapsed');
    document.querySelector('.container').classList.remove('sidebar-expanded');
}

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
});
