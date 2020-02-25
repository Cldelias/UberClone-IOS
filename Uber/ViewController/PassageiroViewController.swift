//
//  PassageiroViewController.swift
//  Uber
//
//  Created by Guilherme Magnabosco on 01/02/20.
//  Copyright © 2020 Guilherme Magnabosco. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseDatabase
import MapKit

class PassageiroViewController: UIViewController , CLLocationManagerDelegate{

    @IBOutlet weak var enderecoDestinoCampo: UITextField!
    @IBOutlet weak var mapa: MKMapView!
    var gerenciadorLocalizacao = CLLocationManager()
    var localUsuario = CLLocationCoordinate2D()
    var localMotorista = CLLocationCoordinate2D()
    var uberChamado: Bool = false
    var uberACaminho: Bool = false
    @IBOutlet weak var botaoChamar: UIButton!
    
    
    @IBOutlet weak var areaEndereco: UIView!
    @IBOutlet weak var marcadorLocalPassageiro: UIView!
    @IBOutlet weak var marcadorLocalDestino: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        gerenciadorLocalizacao.delegate = self
        gerenciadorLocalizacao.desiredAccuracy = kCLLocationAccuracyBest
        gerenciadorLocalizacao.requestWhenInUseAuthorization()
        gerenciadorLocalizacao.startUpdatingLocation()
        
        //Configura arredondamento dos marcadores
        self.marcadorLocalPassageiro.layer.cornerRadius = 10
        self.marcadorLocalPassageiro.clipsToBounds = true
        
        self.marcadorLocalDestino.layer.cornerRadius = 10
        self.marcadorLocalDestino.clipsToBounds = true
        
        self.areaEndereco.layer.cornerRadius = 10
        self.areaEndereco.clipsToBounds = true
        
        //Verifica se usuario ja tem requisicao de uber
        let database = Database.database().reference()
        let autenticacao = Auth.auth()
        
        if let emailUsuario = autenticacao.currentUser?.email {
            
            let requisicoes = database.child("requisicoes")
            let consultaRequisicoes = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: emailUsuario)
            
            // Adiciona ouvinte para quando usuario chamar Uber
            consultaRequisicoes.observe(.childAdded) { (snapshot) in
                
                if snapshot.value != nil  {
                    self.alteraBotaoCancelar()
                }
                
            }
            
            // Adiciona ouvinte para quando motorista aceitar corrida
            consultaRequisicoes.observe(.childChanged) { (snapshot) in
                
                if let dados = snapshot.value as? [String: Any] {
                    if let status = dados["status"] as? String {
                        if status == StatusCorrida.PegarPassageiro.rawValue {
                            if let latMotorista = dados["motoristaLatitude"] {
                                if let lonMotorista = dados["motoristaLongitude"] {
                                    self.localMotorista = CLLocationCoordinate2D(latitude: latMotorista as! CLLocationDegrees, longitude: lonMotorista as! CLLocationDegrees)
                                    self.exibirMotoristaPassageiro()
                                }
                            }
                        } else if status == StatusCorrida.EmViagem.rawValue {
                            self.alteraBotaoEmViagem()
                        } else if status == StatusCorrida.ViagemFinalizada.rawValue {
                            if let preco = dados["precoViagem"] as? Double {
                                self.alteraBotaoViagemFinalizada(preco: preco)
                            }
                        }
                    }
                
                }
                
                
            }
            
        }

    }
    func alteraBotaoViagemFinalizada(preco: Double) {
        
        self.botaoChamar.isEnabled = false
        self.botaoChamar.backgroundColor = UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1)
        
        //Formata numero
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        nf.locale = Locale(identifier: "pt-BR")
        let precoFinal = nf.string(from: NSNumber(value: preco))
        
        
        self.botaoChamar.setTitle("Viagem Finalizada - R$" + precoFinal!, for: .normal)

    }
    
    func exibirMotoristaPassageiro()  {
        
        self.uberACaminho = true
        
        //Calcular distancia entre motorista e passageiro
        var mensagem = ""
        let motoristaLocation = CLLocation(latitude: self.localMotorista.latitude, longitude: self.localMotorista.longitude)
        let passageiroLocation = CLLocation(latitude: self.localUsuario.latitude, longitude: self.localUsuario.longitude)
        let distancia = motoristaLocation.distance(from: passageiroLocation)
        let distanciaKm = distancia/1000
        let distanciaFinal = round(distanciaKm)
        mensagem = "Motorista \(distanciaFinal) Km distante"
        
        if distanciaKm < 1 {
            let distanciaM = round(distancia)
            mensagem = "Motorista \(distanciaM) metros distante"
        }
        
        self.botaoChamar.backgroundColor = UIColor(displayP3Red: 0.067, green: 0.576, blue: 0.604, alpha: 1)
        self.botaoChamar.setTitle(mensagem, for: .normal)
        
        //Exibir motorista e passageiro no mapa
        mapa.removeAnnotations(mapa.annotations)
        
        let latDiferenca = abs(self.localUsuario.latitude - self.localMotorista.latitude) * 300000
        let lonDiferenca = abs(self.localUsuario.longitude - self.localMotorista.longitude) * 300000

        let regiao = MKCoordinateRegion(center: self.localUsuario, latitudinalMeters: latDiferenca, longitudinalMeters: lonDiferenca)
        mapa.setRegion(regiao, animated: true)
        
        //Anotacao motorista
        let anotacaMotorista = MKPointAnnotation()
        anotacaMotorista.coordinate = self.localMotorista
        anotacaMotorista.title = "Motorista"
        mapa.addAnnotation(anotacaMotorista)
        
        //Anotacao passageiro
        let anotacaoPassageiro = MKPointAnnotation()
        anotacaoPassageiro.coordinate = self.localUsuario
        anotacaoPassageiro.title = "Passageiro"
        mapa.addAnnotation(anotacaoPassageiro)
        
        
    }
    
    
    @IBAction func chamarUber(_ sender: Any) {
        
        let database =  Database.database().reference()
        let autenticacao = Auth.auth()
        let requisicao = database.child("requisicoes")
        
        if let emailUsuario = autenticacao.currentUser?.email {
            
            if self.uberChamado { //Uber chamado
                
                self.alteraBotaoChamar()
                
                //remover requisicao
                let requisicao = database.child("requisicoes")
                
                requisicao.queryOrdered(byChild: "email").queryEqual(toValue: emailUsuario).observeSingleEvent(of: .childAdded) { (snapshot) in
                    
                    snapshot.ref.removeValue()
                    
                }
                
            } else { // Uber nao foi chamado
                
                self.salvarRequisicao()
                        
            }
                    
        }
        
    }
    
    func salvarRequisicao() {
        
        let database =  Database.database().reference()
        let autenticacao = Auth.auth()
        let requisicao = database.child("requisicoes")
        
        if let idUsuario = autenticacao.currentUser?.uid {
            if let emailUsuario = autenticacao.currentUser?.email {
                if let enderecoDestino = self.enderecoDestinoCampo.text {
                    if enderecoDestino != "" {
                        
                        CLGeocoder().geocodeAddressString(enderecoDestino) { (local, erro) in
                            
                            if erro == nil {
                                if let dadosLocal = local?.first {
                                    
                                    var rua = ""
                                    if dadosLocal.thoroughfare != nil  {
                                        rua = dadosLocal.thoroughfare!
                                    }
                                    
                                    var numero = ""
                                    if dadosLocal.subThoroughfare != nil  {
                                        numero = dadosLocal.subThoroughfare!
                                    }
                                    
                                    var bairro = ""
                                    if dadosLocal.subLocality! != nil  {
                                        bairro = dadosLocal.subLocality!
                                    }
                                    
                                    var cidade = ""
                                    if dadosLocal.locality! != nil  {
                                        cidade = dadosLocal.locality!
                                    }
                                    
                                    var cep = ""
                                    if dadosLocal.postalCode! != nil  {
                                        cep = dadosLocal.postalCode!
                                    }
                                    
                                    let enderecoCompleto = "\(rua), \(numero), \(bairro) - \(cidade) - \(cep)"
                                    
                                    if let latDestino = dadosLocal.location?.coordinate.latitude {
                                        if let lonDestino = dadosLocal.location?.coordinate.longitude {
                                            
                                            let alerta = UIAlertController(title: "Confirme seu endereço!", message: enderecoCompleto, preferredStyle: .alert)
                                            
                                            let acaoCancelar = UIAlertAction(title: "Cancelar", style: .cancel, handler: nil)
                                            
                                            let acaoConfirmar = UIAlertAction(title: "Confirmar", style: .default) { (alertAction) in
                                                
                                                //Recuperar nome do usuario
                                                let database =  Database.database().reference()
                                                let usuarios = database.child("usuarios").child(idUsuario)
                                                
                                                usuarios.observeSingleEvent(of: .value) { (snapshot) in
                                                    
                                                    let dados = snapshot.value as? NSDictionary
                                                    let nomeUsuario = dados!["nome"] as? String
                                                    
                                                    self.alteraBotaoCancelar()
                                                    
                                                    // Salvar dados da requisicao
                                                    let dadosUsuario = [
                                                        "destinoLatitude": latDestino,
                                                        "destinoLongitude": lonDestino,
                                                        "email": emailUsuario,
                                                        "nome" : nomeUsuario,
                                                        "latitude": self.localUsuario.latitude,
                                                        "longitude": self.localUsuario.longitude
                                                        ] as [String : Any]
                                                    
                                                    requisicao.childByAutoId().setValue(dadosUsuario)
                                                    
                                                    self.alteraBotaoCancelar()
                                                }
                                                
                                            }
                                            
                                            alerta.addAction(acaoCancelar)
                                            alerta.addAction(acaoConfirmar)
                                            
                                            self.present(alerta, animated: true, completion: nil)
                                            
                                        }
                                    }
                                    
                                }
                            }
                            
                        }
                        
                    } else {
                        print("Endereco nao digitado!")
                    }
                }
                
            }
            
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        //Recupera as coordenadas do local atual
        if let coordenadas = manager.location?.coordinate {
            
            //Configura posicao atual do usuario
            self.localUsuario = coordenadas
            
            if self.uberACaminho {
                self.exibirMotoristaPassageiro()
            } else {
            
                let regiao = MKCoordinateRegion(center: coordenadas, latitudinalMeters: 200, longitudinalMeters:200)
                mapa.setRegion(regiao, animated: true)
                
                //Remove anotacoes antes de criar
                mapa.removeAnnotations(mapa.annotations)
                
                // Cria uma anotacao para a posicao atual do usuario
                let anotacaoUsuario = MKPointAnnotation()
                anotacaoUsuario.coordinate = coordenadas
                anotacaoUsuario.title = "Seu local"
                mapa.addAnnotation(anotacaoUsuario)
            }
            
        }
        
        
    }
    
    @IBAction func deslogarUsuario(_ sender: Any) {
      
      let autenticacao = Auth.auth()
      do {
          try autenticacao.signOut()
          dismiss(animated: true, completion: nil)
      } catch {
          print("Não foi possivel deslogar usuario!")
      }
        
    }
    
    func alteraBotaoEmViagem() {
        
        self.botaoChamar.setTitle("Em viagem", for: .normal)
        self.botaoChamar.isEnabled = false
        self.botaoChamar.backgroundColor = UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1)
        
    }
    
    func alteraBotaoCancelar() {
        
        self.botaoChamar.setTitle("Cancelar Uber", for: .normal)
        self.botaoChamar.backgroundColor = UIColor(displayP3Red: 0.831, green: 0.237, blue: 0.146, alpha: 1)
        self.uberChamado = true
        
    }
    
    func alteraBotaoChamar() {
        
        self.botaoChamar.setTitle("Chamar Uber", for: .normal)
        self.botaoChamar.backgroundColor = UIColor(displayP3Red: 0.067, green: 0.576, blue: 0.604, alpha: 1)
        self.uberChamado = false
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
