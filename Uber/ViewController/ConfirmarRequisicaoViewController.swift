//
//  ConfirmarRequisicaoViewController.swift
//  Uber
//
//  Created by Guilherme Magnabosco on 04/02/20.
//  Copyright © 2020 Guilherme Magnabosco. All rights reserved.
//

import UIKit
import MapKit
import FirebaseDatabase
import FirebaseAuth


class ConfirmarRequisicaoViewController: UIViewController, CLLocationManagerDelegate {

    
    @IBOutlet weak var mapa: MKMapView!
    @IBOutlet weak var botaoAceitarCorrida: UIButton!
    var gerenciadorLocalizacao = CLLocationManager()
    
    var nomePassageiro = ""
    var emailPassageiro = ""
    var localPassageiro = CLLocationCoordinate2D()
    var localMotorista = CLLocationCoordinate2D()
    var localDestino = CLLocationCoordinate2D()
    var status: StatusCorrida = .EmRequisicao
    
    @IBAction func aceitarCorrida(_ sender: Any) {
        
        if self.status == StatusCorrida.EmRequisicao {
            //Atualizar a requisicao
            let database = Database.database().reference()
            let requisicoes = database.child("requisicoes")
            let autenticacao = Auth.auth()
            
            if let emailMotorista = autenticacao.currentUser?.email {
                
                requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro).observeSingleEvent(of: .childAdded) { (snapshot) in
                    
                    let dadosMotorista = [
                        "motoristaEmail": emailMotorista,
                        "motoristaLatitude": self.localMotorista.latitude,
                        "motoristaLongitude": self.localMotorista.longitude,
                        "status": StatusCorrida.PegarPassageiro.rawValue
                        ] as [String : Any]
                    
                    snapshot.ref.updateChildValues(dadosMotorista)
                    self.pegarPassageiro()
                    
                }
            }
            
            //Exibir caminho no mapa
            let passageiroCLL = CLLocation(latitude: localPassageiro.latitude, longitude: localPassageiro.longitude)
            
            CLGeocoder().reverseGeocodeLocation(passageiroCLL) { (local, erro) in
                
                if erro == nil {
                    if let dadosLocal = local?.first {
                        
                        let placemark = MKPlacemark(placemark: dadosLocal)
                        
                        let mapaItem = MKMapItem(placemark: placemark)
                        mapaItem.name = self.nomePassageiro
                        
                        let opcoes = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                        mapaItem.openInMaps(launchOptions: opcoes)
                        
                    }
                }
                
            }
        } else if self.status == StatusCorrida.IniciarViagem {
            
            self.iniciarViagemDestino()
            
        } else if self.status == StatusCorrida.EmViagem {
            
            self.finalizarViagem()
            
        }
        
    }
    
    func finalizarViagem() {
        
        //Altera status
        self.status = .ViagemFinalizada
        
        //Calcula preco da viagem
        let precoKm: Double = 4
        
        //Recupera dados para atualizar o preco
        let database = Database.database().reference()
        let requisicoes = database.child("requisicoes")
        let consultaRequisicoes = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro)
        
        consultaRequisicoes.observeSingleEvent(of: .childAdded) { (snapshot) in
            
            if let dados = snapshot.value as? [String: Any] {
                if let latI = dados["latitude"] as? Double {
                    if let lonI = dados["longitude"] as? Double {
                        if let lonD = dados["destinoLongitude"] as? Double {
                            if let latD = dados["destinoLatitude"] as? Double {
                                
                                let inicioLocation = CLLocation(latitude: latI, longitude: lonI)
                                
                                let destinoLocation = CLLocation(latitude: latD, longitude: lonD)
                                
                                //calcular distancia
                                let distancia = inicioLocation.distance(from: destinoLocation)
                                let distanciaKm = distancia/1000
                                let precoViagem = distanciaKm * precoKm
                                
                                let dadosAtualizar = [
                                    "precoViagem": precoViagem,
                                    "distanciaPercorrida": distanciaKm
                                ]
                                
                                snapshot.ref.updateChildValues(dadosAtualizar)
                                
                                //Atualiza requisicao no Firebase
                                self.atualizarStatusRequisicao(status: self.status.rawValue)
                                
                                //Alterna para viagem finalizada
                                self.alteraBotaoViagemFinalizada(preco: precoViagem)
                                
                            }
                        }
                    }
                }
            }
            
        }
        
    }
    
    func iniciarViagemDestino() {
        
        //Altera status
        self.status = .EmViagem
        
        //Atualizar no firebase
        self.atualizarStatusRequisicao(status: self.status.rawValue)
        
        //Exibir caminho no mapa
        let destinoCLL = CLLocation(latitude: localDestino.latitude, longitude: localDestino.longitude)
        
        CLGeocoder().reverseGeocodeLocation(destinoCLL) { (local, erro) in
            
            if erro == nil {
                if let dadosLocal = local?.first {
                    
                    let placemark = MKPlacemark(placemark: dadosLocal)
                    
                    let mapaItem = MKMapItem(placemark: placemark)
                    mapaItem.name = "Destino passageiro"
                    
                    let opcoes = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
                    mapaItem.openInMaps(launchOptions: opcoes)
                    
                }
            }
        }
        
    }
    
    func pegarPassageiro() {
        
        //Alterar o status do passageiro
        self.status = .PegarPassageiro  
        //AlternarBotao
        self.alteraBotaoPegarPassageiro()
        
    }
    
    func atualizarStatusRequisicao(status: String) {
        
        if status != nil && self.emailPassageiro != "" {
            
            let database = Database.database().reference()
            let requisicoes = database.child("requisicoes")
            let consultaRequisicao = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro)
            
            consultaRequisicao.observeSingleEvent(of: .childAdded) { (snapshot) in
                
                if let dados = snapshot.value as? [String: Any] {
                    let dadosAtualizar = [
                        "status": status
                    ]
                    
                    snapshot.ref.updateChildValues(dadosAtualizar)
                }
                
            }
            
        }
        
    }
    
    func exibeMotoristaPassageiro(lPartida: CLLocationCoordinate2D, lDestino: CLLocationCoordinate2D, tPartida: String, tDestino: String) {
        
        //Exibir motorista e passageiro no mapa
        mapa.removeAnnotations(mapa.annotations)
        
        let latDiferenca = abs(lPartida.latitude - lDestino.latitude) * 300000
        let lonDiferenca = abs(lPartida.longitude - lDestino.longitude) * 300000

        let regiao = MKCoordinateRegion(center: lPartida, latitudinalMeters: latDiferenca, longitudinalMeters: lonDiferenca)
        mapa.setRegion(regiao, animated: true)
        
        //Anotacao partida
        let anotacaoPartida = MKPointAnnotation()
        anotacaoPartida.coordinate = lPartida
        anotacaoPartida.title = tPartida
        mapa.addAnnotation(anotacaoPartida)
        
        //Anotacao destino
        let anotacaoDestino = MKPointAnnotation()
        anotacaoDestino.coordinate = lDestino
        anotacaoDestino.title = tDestino
        mapa.addAnnotation(anotacaoDestino)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        gerenciadorLocalizacao.delegate = self
        gerenciadorLocalizacao.desiredAccuracy = kCLLocationAccuracyBest
        gerenciadorLocalizacao.requestWhenInUseAuthorization()
        gerenciadorLocalizacao.startUpdatingLocation()
        gerenciadorLocalizacao.allowsBackgroundLocationUpdates = true
        
        //Configurar area inicial do mapa
        let regiao = MKCoordinateRegion(center: self.localPassageiro, latitudinalMeters: 200, longitudinalMeters: 200)
        mapa.setRegion(regiao, animated: true)
        
        // adiciona anotacoa passageiro
        let anotacaoPassageiro = MKPointAnnotation()
        anotacaoPassageiro.coordinate = self.localPassageiro
        anotacaoPassageiro.title = self.nomePassageiro
        mapa.addAnnotation(anotacaoPassageiro)
        
        //Recuperar status da requisicao e ajustar interface
        let database = Database.database().reference()
        
        let requisicoes = database.child("requisicoes")
        let consultaRequisicoes = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro)
        
        consultaRequisicoes.observe(.childChanged) { (snapshot) in
            
            if let dados = snapshot.value as? [String: Any] {
                if let statusR = dados["status"] as? String {
                    self.recarregarTelaStatus(status: statusR, dados: dados)
                }
            }
            
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        //Recuperar status da requisicao e ajustar interface
        let database = Database.database().reference()
        
        let requisicoes = database.child("requisicoes")
        let consultaRequisicoes = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: self.emailPassageiro)
        
        consultaRequisicoes.observeSingleEvent(of: .childAdded) { (snapshot) in
            
            if let dados = snapshot.value as? [String: Any] {
                if let statusR = dados["status"] as? String {
                    self.recarregarTelaStatus(status: statusR, dados: dados)
                }
            }
            
        }
        
    }
    
    func recarregarTelaStatus(status: String, dados: [String: Any]) {
        
        //Carregar a tela baseado no status
        if status == StatusCorrida.PegarPassageiro.rawValue {
            print("Status pegar passageiro")
            self.pegarPassageiro()
            
            self.exibeMotoristaPassageiro(lPartida: self.localMotorista, lDestino: self.localPassageiro, tPartida: "Meu local", tDestino: "Passageiro")
            
        } else if status == StatusCorrida.IniciarViagem.rawValue {
            self.alteraBotaoIniciarViagem()
            self.status = .IniciarViagem
            print("Status Iniciar viagem")
            
            //Recupera local de destino
            if let latDestino = dados["destinoLatitude"] as? Double {
                if let lonDestino = dados["destinoLongitude"] as? Double {
                    //Configura local de destino
                    self.localPassageiro = CLLocationCoordinate2D(latitude: latDestino, longitude: lonDestino)
                }
            }
            
            //Exibir motorista passageiro
            self.exibeMotoristaPassageiro(lPartida: self.localMotorista, lDestino: self.localPassageiro, tPartida: "Motorista", tDestino: "Passageiro")
        } else if (status == StatusCorrida.EmViagem.rawValue) {
            
            //Alterar status
            self.status = .EmViagem
            
            //Alterna botao
            self.alteraBotaoPendenteFinalizarViagem()
            
            //atualizar local destino passageiro
            if let latDestino = dados["destinoLatitude"] as? Double {
                if let lonDestino = dados["destinoLongitude"] as? Double {
                    //Configura local de destino
                    self.localDestino = CLLocationCoordinate2D(latitude: latDestino, longitude: lonDestino)
                    
                    //Exibir motorista passageiro
                    self.exibeMotoristaPassageiro(lPartida: self.localMotorista, lDestino: self.localPassageiro, tPartida: "Motorista", tDestino: "Destino")
                }
            }
        } else if status == StatusCorrida.ViagemFinalizada.rawValue {
            self.status = .ViagemFinalizada
            if let preco = dados["precoViagem"] as? Double {
                
                self.alteraBotaoViagemFinalizada(preco: preco)

            }
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if let coordenadas = manager.location?.coordinate {
            self.localMotorista = coordenadas
            self.atualizarLocalMotorista()
        }
        
    }
    
    func atualizarLocalMotorista() {
        
        //Atualizar localizacao do motorista no firebase
        let database = Database.database().reference()
        
        if self.emailPassageiro != "" {
            
            let requisicoes = database.child("requisicoes")
            let consultaRequisicao = requisicoes.queryOrdered(byChild: "email").queryEqual(toValue: emailPassageiro)
            
            consultaRequisicao.observeSingleEvent(of: .childAdded) { (snapshot) in
                
                //print("entrei")
                if let dados = snapshot.value as? [String: Any] {
                    if let statusR = dados["status"] as? String {
                        
                        //Status pegar passageiro
                        if statusR == StatusCorrida.PegarPassageiro.rawValue {
                            
                            //Verifica se o motorista esta proximo, para inicar corrida
                            let motoristaLocation = CLLocation(latitude: self.localMotorista.latitude, longitude: self.localMotorista.longitude)
                            let passageiroLocation = CLLocation(latitude: self.localPassageiro.latitude, longitude: self.localPassageiro.longitude)
                            
                            //Calcular distancia entre motorista e passageiro
                            let distancia = motoristaLocation.distance(from: passageiroLocation)
                            let distanciaKm = distancia/1000
                            
                            if distanciaKm <= 0.5 {
                                // Atualizar status
                                self.atualizarStatusRequisicao(status: StatusCorrida.IniciarViagem.rawValue)
                            }
                            
                        } else if (statusR == StatusCorrida.IniciarViagem.rawValue) {
                            
                            //self.alteraBotaoIniciarViagem()
                            
                            //Exibir motorista passageiro
                            self.exibeMotoristaPassageiro(lPartida: self.localMotorista, lDestino: self.localPassageiro, tPartida: "Motorista", tDestino: "Passageiro")
                            
                        } else if (statusR == StatusCorrida.EmViagem.rawValue) {
                            
                            if let latDestino = dados["destinoLatitude"] as? Double {
                                if let lonDestino = ["destinoLongitude"] as? Double {
                                    
                                    self.localDestino = CLLocationCoordinate2D(latitude: latDestino, longitude: lonDestino)
                                    
                                    //Exibe motorista destino
                                    self.exibeMotoristaPassageiro(lPartida: self.localMotorista, lDestino: self.localDestino, tPartida: "Motorista", tDestino: "Destino")
                                    
                                }
                            }
                            
                        }
                        
                    }
                    
                    let dadosMotorista = [
                        "motoristaLatitude": self.localMotorista.latitude,
                        "motoristaLongitude": self.localMotorista.longitude,
                        ] as [String : Any]
                    
                    //Salvar dados no firebase
                    snapshot.ref.updateChildValues(dadosMotorista)
                }
                
            }
            
        }
        
    }
    func alteraBotaoViagemFinalizada(preco: Double) {
        
        self.botaoAceitarCorrida.isEnabled = false
        self.botaoAceitarCorrida.backgroundColor = UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1)
        
        //Formata numero
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        nf.locale = Locale(identifier: "pt-BR")
        let precoFinal = nf.string(from: NSNumber(value: preco))
        
        
        self.botaoAceitarCorrida.setTitle("Viagem Finalizada - R$" + precoFinal!, for: .normal)

        
    }
    
    func alteraBotaoIniciarViagem() {
        
        self.botaoAceitarCorrida.setTitle("Iniciar viagem", for: .normal)
        self.botaoAceitarCorrida.isEnabled = true
        self.botaoAceitarCorrida.backgroundColor = UIColor(displayP3Red: 0.067, green: 0.576, blue: 0.604, alpha: 1)
        
    }
    
    func alteraBotaoPendenteFinalizarViagem() {
        
        self.botaoAceitarCorrida.setTitle("Finalizar Viagem", for: .normal)
        self.botaoAceitarCorrida.isEnabled = true
        self.botaoAceitarCorrida.backgroundColor = UIColor(displayP3Red: 0.067, green: 0.576, blue: 0.604, alpha: 1)
        
    }
    
    func alteraBotaoPegarPassageiro() {
        
        self.botaoAceitarCorrida.setTitle("A caminho do passageiro", for: .normal)
        self.botaoAceitarCorrida.isEnabled = false
        self.botaoAceitarCorrida.backgroundColor = UIColor(displayP3Red: 0.502, green: 0.502, blue: 0.502, alpha: 1)
        
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
