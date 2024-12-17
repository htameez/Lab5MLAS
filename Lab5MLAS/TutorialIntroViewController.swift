//
//  TutorialIntroViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/25/24.
//  Updated on 11/27/24.
//

import UIKit

class TutorialIntroViewController: UIViewController {

    // UI Components
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let nextButton = UIButton(type: .system)

    // Current step in the tutorial
    private var currentStep = 0

    // Tutorial Steps
    private let steps: [(image: String, title: String, description: String)] = [
        ("welcome_image", "Welcome to Alif Ba Ta!", "Your interactive guide to mastering the Arabic alphabet through personalized handwriting exercises. Let’s take a quick tour to get you started!"),
        ("learn_mode_image", "Learn Mode", "Discover the foundation of the Arabic alphabet through guided handwriting exercises with real-time feedback and audio assistance."),
        ("quiz_mode_image", "Quiz Mode", "Test your memory by writing letters from audio prompts. Track your progress and review missed letters."),
        ("missed_letter_image", "Missed Letter Practice", "Revisit and perfect letters you missed in Quiz Mode with focused practice and audio assistance."),
        ("start_learning_image", "You’re All Set!", "Dive into Learn Mode and begin your journey to mastering the Arabic alphabet today!")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateStep()
    }

    // MARK: - UI Setup
    private func setupUI() {
        // Set background color
        view.backgroundColor = .black

        // Configure ImageView
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        // Configure Title Label
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .white // White text for black background
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Configure Description Label
        descriptionLabel.font = UIFont.systemFont(ofSize: 12)
        descriptionLabel.textAlignment = .center
        descriptionLabel.textColor = .white // White text for black background
        descriptionLabel.numberOfLines = 0
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(descriptionLabel)

        // Configure Next Button
        nextButton.setTitle("Next", for: .normal)
        nextButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.layer.cornerRadius = 10
        nextButton.backgroundColor = .darkGray
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nextButton)

        // Set Constraints
        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // ImageView Constraints
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6), // Image takes 60% of screen height

            // Title Label Constraints
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Description Label Constraints
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Next Button Constraints
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.heightAnchor.constraint(equalToConstant: 50),
            nextButton.widthAnchor.constraint(equalToConstant: 150)
        ])
    }

    // MARK: - Update Tutorial Step
    private func updateStep() {
        guard currentStep < steps.count else {
            finishTutorial()
            return
        }

        // Get the current step data
        let step = steps[currentStep]
        imageView.image = UIImage(named: step.image)
        titleLabel.text = step.title
        descriptionLabel.text = step.description

        // Update the button text for the last step
        nextButton.setTitle(currentStep == steps.count - 1 ? "Start Learning" : "Next", for: .normal)
    }

    // MARK: - Actions
    @objc private func nextButtonTapped() {
        currentStep += 1
        updateStep()
    }

    private func finishTutorial() {
        // Save tutorial completion state
        UserDefaults.standard.set(true, forKey: "hasSeenTutorial")

        // Instantiate the HomeViewController from the storyboard
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeViewController") as? HomeViewController {
            navigationController?.setViewControllers([homeVC], animated: true)
        }
    }

}

