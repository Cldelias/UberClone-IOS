//
//  EntrarViewController.swift
//  Uber
//
//  Created by Guilherme Magnabosco on 31/01/20.
//  Copyright © 2020 Guilherme Magnabosco. All rights reserved.
//

import UIKit
import FirebaseAuth

class EntrarViewController: UIViewController {

    
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var senha: UITextField!
    
        
    @IBAction func entrar(_ sender: Any) {
        
        let retorno = self.validarCampos()
        if retorno == "" {
            
        //Faz autenticacao do usuario
        let autenticacao = Auth.auth()
            
        if let emailR = self.email.text {
            if let senhaR = self.senha.text {
                        
                autenticacao.signIn(withEmail: emailR, password: senhaR) { (usuario, erro) in
                    if erro == nil {
                        
                        /* Valida se o usuario esta logado
                           Caso o usuario esteja logado,
                           sera redirecionado automaticamente de acordo
                           com o tipo de usuario com evento criado na View controller
                         */
                        
                        if usuario == nil {
                            print("Erro ao lugar usuario!")
                        }

                    } else {
                        print("Erro ao autenticar usuario.")
                    }
                }
                        
            }
        }
                        
        } else {
            
             print("O campo \(retorno) não foi preenchido.")
            
        }
        
    }
    
    func validarCampos() -> String {
        
        if self.email.text!.isEmpty {
            return "E-mail"
        } else if self.senha.text!.isEmpty {
            return "Senha"
        }
        
        return ""
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setNavigationBarHidden(false, animated: false)
    }

}
