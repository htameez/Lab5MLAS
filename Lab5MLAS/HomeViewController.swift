//
//  HomeViewController.swift
//  Lab5MLAS
//
//  Created by Hamna Tameez on 11/25/24.
//  Updated on 11/27/24.
//


import UIKit
import Network

class HomeViewController: UIViewController {

    // MARK: - UI Components
    private let titleLabel = UILabel()
    private let arabicLabel = UILabel()
    private let messageLabel = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let lessonsStackView = UIStackView()
    private var lessonButtons: [UIButton] = []
    private let practiceMissedButton = UIButton(type: .system)
    private let masterQuizButton = UIButton(type: .system)

    let client = MlaasModel()

    // Progress Tracking
    private var completedLessons = 0 // Tracks the number of lessons completed

    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .black

        setupUI()
        setupConstraints()

        // Start dataset preparation
        startPreparingDataset()

        // Clear missedLetters on app launch
        UserDefaults.standard.removeObject(forKey: "missedLetters")
        UserDefaults.standard.synchronize()
    }
    

    // MARK: - UI Setup
    private func setupUI() {
        // Title Label
        titleLabel.text = "Welcome to Alif Ba Ta!"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textColor = UIColor.systemBlue
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Arabic Title Label
        arabicLabel.text = "مرحبًا بكم في ألف باء تاء"
        arabicLabel.textAlignment = .center
        arabicLabel.font = UIFont.systemFont(ofSize: 22, weight: .medium)
        arabicLabel.textColor = UIColor.systemBlue
        arabicLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arabicLabel)

        // Message Label
        messageLabel.text = "Preparing dataset..."
        messageLabel.font = UIFont.systemFont(ofSize: 18)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)

        // Activity Indicator
        activityIndicator.color = .systemBlue
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)

        // Lessons Stack View
        lessonsStackView.axis = .vertical
        lessonsStackView.spacing = 20
        lessonsStackView.alignment = .center
        lessonsStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lessonsStackView)

        // Create Lesson Buttons
        for i in 1...4 { // Update to only 4 levels
            let button = UIButton(type: .system)
            
            // Use UIButton.Configuration for iOS 15+
            var configuration = UIButton.Configuration.filled()
            configuration.title = "Lesson \(i)"
            configuration.baseForegroundColor = .white
            configuration.baseBackgroundColor = i == 1 ? UIColor.systemBlue : UIColor.darkGray
            configuration.cornerStyle = .capsule
            configuration.image = i == 1 ? nil : UIImage(systemName: "lock.fill") // Add lock icon for locked lessons
            configuration.imagePlacement = .leading // Place the icon to the left of the text
            configuration.imagePadding = 10 // Add spacing between icon and text
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20) // Adjust padding

            button.configuration = configuration
            button.tag = i
            button.isEnabled = i == 1 // Only enable Lesson 1 initially
            button.addTarget(self, action: #selector(lessonButtonTapped(_:)), for: .touchUpInside)
            
            lessonButtons.append(button)
            lessonsStackView.addArrangedSubview(button)
            
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 250).isActive = true
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        }

        // Practice Missed Letters Button
        var practiceConfiguration = UIButton.Configuration.filled()
        practiceConfiguration.title = "Practice Missed Letters"
        practiceConfiguration.baseForegroundColor = .white
        practiceConfiguration.baseBackgroundColor = UIColor.darkGray // Locked state color
        practiceConfiguration.cornerStyle = .capsule
        practiceConfiguration.image = UIImage(systemName: "lock.fill") // Lock icon
        practiceConfiguration.imagePlacement = .leading
        practiceConfiguration.imagePadding = 10
        practiceConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)

        practiceMissedButton.configuration = practiceConfiguration
        practiceMissedButton.isEnabled = false // Initially locked
        practiceMissedButton.addTarget(self, action: #selector(practiceMissedLettersTapped), for: .touchUpInside)

        lessonsStackView.addArrangedSubview(practiceMissedButton)
        practiceMissedButton.translatesAutoresizingMaskIntoConstraints = false
        practiceMissedButton.widthAnchor.constraint(equalToConstant: 250).isActive = true
        practiceMissedButton.heightAnchor.constraint(equalToConstant: 60).isActive = true

        // Master Quiz Button
        let masterQuizButton = UIButton(type: .system)
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Master Quiz"
        configuration.baseForegroundColor = .white
        configuration.baseBackgroundColor = UIColor(red: 0.0, green: 0.1, blue: 0.4, alpha: 1.0)
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20)

        masterQuizButton.configuration = configuration
        masterQuizButton.isEnabled = true // Always enabled
        masterQuizButton.addTarget(self, action: #selector(masterQuizTapped), for: .touchUpInside)
        lessonsStackView.addArrangedSubview(masterQuizButton)

        masterQuizButton.translatesAutoresizingMaskIntoConstraints = false
        masterQuizButton.widthAnchor.constraint(equalToConstant: 250).isActive = true
        masterQuizButton.heightAnchor.constraint(equalToConstant: 60).isActive = true


    }

    // MARK: - Constraints
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title Label
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Arabic Title Label
            arabicLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            arabicLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            arabicLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            arabicLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 55),

            // Message Label
            messageLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Lessons Stack View
            lessonsStackView.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 40),
            lessonsStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // MARK: - Button Actions
    @objc private func lessonButtonTapped(_ sender: UIButton) {
        let lesson = sender.tag
        if lesson <= completedLessons + 1 {
            startLesson(lesson)
        } else {
            showAlert(title: "Lesson Locked", message: "Complete the previous lessons to unlock this one.")
        }
    }

    @objc private func practiceMissedLettersTapped() {
        let missedLetters = UserDefaults.standard.array(forKey: "missedLetters") as? [String] ?? []
        
        if missedLetters.isEmpty {
            showAlert(title: "No Missed Letters", message: "You have no missed letters to practice!")
            return  // Stop further execution
        }
        
        if let missedVC = storyboard?.instantiateViewController(withIdentifier: "MissedLettersTutorialViewController") as? MissedLettersTutorialViewController {
            missedVC.missedLetters = missedLetters
            navigationController?.pushViewController(missedVC, animated: true)
        }
    }
    
    @objc private func masterQuizTapped() {
        let fullAlphabet = [
            "ا", "ب", "ت", "ث", "ج", "ح", "خ",
            "د", "ذ", "ر", "ز", "س", "ش", "ص",
            "ض", "ط", "ظ", "ع", "غ", "ف", "ق",
            "ك", "ل", "م", "ن", "ه", "و", "ي"
        ]
        
        if let quizVC = storyboard?.instantiateViewController(withIdentifier: "QuizViewController") as? QuizViewController {
            quizVC.customLetterList = fullAlphabet // Pass the full alphabet
            quizVC.title = "Master Quiz"
            navigationController?.pushViewController(quizVC, animated: true)
        }
    }

    private func startLesson(_ lesson: Int) {
        if let tutorialViewController = storyboard?.instantiateViewController(withIdentifier: "TutorialViewController") as? TutorialViewController {
            tutorialViewController.currentLessonIndex = lesson - 1 // Pass lesson index (0-based)

            // Pass completion handler to mark the lesson as complete
            tutorialViewController.onLessonComplete = { [weak self] in
                self?.markLessonAsComplete(lesson: lesson)
            }
            
            navigationController?.pushViewController(tutorialViewController, animated: true)
        }
    }
    
    private func navigateToTutorial() {
        if let tutorialViewController = storyboard?.instantiateViewController(withIdentifier: "TutorialViewController") {
            navigationController?.pushViewController(tutorialViewController, animated: true)
        }
    }
    
    func markLessonAsComplete(lesson: Int) {
        guard lesson > 0 && lesson <= lessonButtons.count else { return }

        // Update and save progress
        completedLessons = max(completedLessons, lesson)
        UserDefaults.standard.set(completedLessons, forKey: "completedLessons")
        UserDefaults.standard.synchronize()  // Force immediate save

        // Update buttons
        updateLessonButtons()

        // Unlock buttons
        if completedLessons >= 1 {
            unlockPracticeMissedButton()
        }
    }


    private func unlockPracticeMissedButton() {
        var configuration = practiceMissedButton.configuration
        configuration?.baseBackgroundColor = UIColor.systemPurple // Change to unlocked color
        configuration?.image = nil // Remove lock icon
        practiceMissedButton.configuration = configuration
        practiceMissedButton.isEnabled = true
    }

    private func completeLesson(_ lesson: Int) {
        if lesson == completedLessons + 1 {
            completedLessons += 1
            unlockNextLesson()
        }
    }

    private func unlockNextLesson() {
        for (index, button) in lessonButtons.enumerated() {
            if index < completedLessons {
                button.backgroundColor = UIColor.systemBlue
                button.setImage(nil, for: .normal)
                button.isEnabled = true
            } else if index == completedLessons {
                button.backgroundColor = UIColor.systemBlue
                button.setImage(nil, for: .normal)
                button.isEnabled = true
            } else {
                button.backgroundColor = UIColor.darkGray
                button.setImage(UIImage(systemName: "lock.fill"), for: .normal)
                button.isEnabled = false
            }
        }

        // Unlock the "Master Quiz" button after the 4th lesson
        if completedLessons == 4 {
            var configuration = masterQuizButton.configuration
            configuration?.baseBackgroundColor = UIColor.systemBlue
            configuration?.image = nil // Remove lock icon
            masterQuizButton.configuration = configuration
            masterQuizButton.isEnabled = true // Enable button
        }
    }
    
    private func updateLessonButtons() {
        for (index, button) in lessonButtons.enumerated() {
            if index < completedLessons {
                button.configuration?.baseBackgroundColor = UIColor.systemBlue
                button.configuration?.image = nil
                button.isEnabled = true
            } else if index == completedLessons {
                button.configuration?.baseBackgroundColor = UIColor.systemBlue
                button.configuration?.image = nil
                button.isEnabled = true
            } else {
                button.configuration?.baseBackgroundColor = UIColor.darkGray
                button.configuration?.image = UIImage(systemName: "lock.fill")
                button.isEnabled = false
            }
        }
    }


    // MARK: - Helper Methods
    private func updateLabelWithFade(_ newText: String) {
        UIView.transition(with: messageLabel,
                          duration: 0.5,
                          options: .transitionCrossDissolve,
                          animations: { self.messageLabel.text = newText },
                          completion: nil)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Dataset Preparation
    private func startPreparingDataset() {
        activityIndicator.startAnimating()
        let dataPath = "/Users/zareenahmurad/Desktop/CS/CS5323/Lab5Python/datasets/ahcd/Train Images 13440x32x32/train"
        
        client.prepareDataset(dsid: 1, dataPath: dataPath) { [weak self] success, errorMessage in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                if success {
                    self?.updateLabelWithFade("Dataset prepared! Start learning!")
                } else {
                    self?.showAlert(title: "Error", message: errorMessage ?? "Dataset preparation failed.")
                }
            }
        }
    }
    
}


