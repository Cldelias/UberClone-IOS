//
//  CadastroViewController.swift
//  Uber
//
//  Created by Guilherme Magnabosco on 31/01/20.
//  Copyright © 2020 Guilherme Magnabosco. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase

class CadastroViewController: UIViewController {

    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var nomeCompleto: UITextField!
    @IBOutlet weak var senha: UITextField!
    @IBOutlet weak var tipoUsuario: UISwitch!
    
    @IBAction func cadastrarUsuario(_ sender: Any) {
        
        let retorno = self.validarCampos()
        if retorno == "" {
            
            //cadastrar usuario no firebase
            let autenticacao = Auth.auth()
            
            if let emailR = self.email.text {
                if let nomeCompletoR = self.nomeCompleto.text {
                    if let senhaR = self.senha.text {
                        
                        autenticacao.createUser(withEmail: emailR, password: senhaR) { (usuario, erro) in

                            if erro == nil {
                                
                                //Validar se o usuario esta logado
                                if usuario != nil {
                                    
                                    //configura database
                                    let database = Database.database().reference()
                                    let usuarios = database.child("usuarios")
                                    
                                    //Verifica tipo do usuario
                                    var tipo = ""
                                    if self.tipoUsuario.isOn {
                                        tipo = "passageiro"
                                    } else {
                                        tipo = "motorista"
                                    }
                                    
                                    //Salva no banco de dados os dados do usuario
                                    let dadosUsuario = [
                                        "email": usuario?.user.email,
                                        "nome": nomeCompletoR,
                                        "tipo": tipo
                                    ]
                                    
                                    //salvar dados
                                    usuarios.child((usuario?.user.uid)!).setValue(dadosUsuario)
                                    
                                     /* Valida se o usuario esta logado
                                        Caso o usuario esteja logado,
                                        sera redirecionado automaticamente de acordo
                                        com o tipo de usuario com evento criado na View controller
                                     */
                                    
                                } else {
                                    print("Erro ao autenticar o usuario.")
                                }
                                
                            } else {
                                print("Erro ao criar conta do usuario.")
                            }
                            
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
        } else if self.nomeCompleto.text!.isEmpty {
            return "Nome Completo"
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
