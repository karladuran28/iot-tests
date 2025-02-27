#include <SoftwareSerial.h>

SoftwareSerial bleSerial(2, 3); // RX, TX

const int trigger=8; 
const int echo=7; 
float dist;

void setup(){
  Serial.begin(9600);
  bleSerial.begin(9600);
  pinMode(trigger,OUTPUT);
  pinMode(echo,INPUT);
}
void loop(){
  digitalWrite(trigger,LOW);
  delayMicroseconds(5);        
  digitalWrite(trigger,HIGH);  
  delayMicroseconds(10);      
  digitalWrite(trigger,LOW); 
  dist=pulseIn(echo,HIGH);      
  dist = dist/58;                  // Se hace la conversión a centímetros
                                   // Si quisieramos convertirlo a pulgadas, dividimos entre 148.

  if (dist < 30) { // Si la distancia es menor a 30cm
    bleSerial.print("Distancia: ");
    bleSerial.print(dist);
    bleSerial.println(" cm");
  }
          
  //Serial.write (10);            
  delay (2000);                
}                             
