using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Security.Cryptography;
using System.IO;

namespace Services
{
    public class CryptoService : ICryptoService
    {
        private readonly string Key = Environment.Development.Key;
        public string Decrypt(string cypherText)
        {
            if (cypherText.Length == 0)
            {
                return (cypherText);
            }
            else
            {
                RijndaelManaged RijndaelCipher = new RijndaelManaged();
                byte[] EncryptedData = Convert.FromBase64String(cypherText);
                byte[] Salt = Encoding.ASCII.GetBytes(Key.Length.ToString());
                PasswordDeriveBytes SecretKey = new PasswordDeriveBytes(Key, Salt);                
                ICryptoTransform Decryptor = RijndaelCipher.CreateDecryptor(SecretKey.GetBytes(16), SecretKey.GetBytes(16));
                MemoryStream memoryStream = new MemoryStream(EncryptedData);                
                CryptoStream cryptoStream = new CryptoStream(memoryStream, Decryptor, CryptoStreamMode.Read);                
                byte[] PlainText = new byte[EncryptedData.Length];                
                int DecryptedCount = cryptoStream.Read(PlainText, 0, PlainText.Length);
                memoryStream.Close();
                cryptoStream.Close();                
                string DecryptedData = Encoding.Unicode.GetString(PlainText, 0, DecryptedCount);                
                return DecryptedData;
            }
        }

        public string Encrypt(string plainText)
        {
            if (plainText.Length == 0)
            {
                return (plainText);
            }
            else
            {
                RijndaelManaged RijndaelCipher = new RijndaelManaged();                
                byte[] PlainText = System.Text.Encoding.Unicode.GetBytes(plainText);                
                byte[] Salt = Encoding.ASCII.GetBytes(Key.Length.ToString());                
                PasswordDeriveBytes SecretKey = new PasswordDeriveBytes(Key, Salt);
                ICryptoTransform Encryptor = RijndaelCipher.CreateEncryptor(SecretKey.GetBytes(16), SecretKey.GetBytes(16));                
                MemoryStream memoryStream = new MemoryStream();
                CryptoStream cryptoStream = new CryptoStream(memoryStream, Encryptor, CryptoStreamMode.Write);                
                cryptoStream.Write(PlainText, 0, PlainText.Length);                
                cryptoStream.FlushFinalBlock();                
                byte[] CipherBytes = memoryStream.ToArray();                
                memoryStream.Close();
                cryptoStream.Close();
                string EncryptedData = Convert.ToBase64String(CipherBytes);                
                return EncryptedData;
            }

        }
    }
}
