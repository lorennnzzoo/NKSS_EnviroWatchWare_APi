using Services;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize(Roles = "Demo")]
    [RoutePrefix("DatabaseProvider")]
    public class DatabaseProviderController : ApiController
    {       
        [HttpGet]
        [Route("GetProviders")]
        public IHttpActionResult GetAll()
        {
            try
            {
                string selectedProvider = System.Configuration.ConfigurationManager.AppSettings["DatabaseProvider"];
                Dictionary<string, bool> providers = new Dictionary<string, bool>
                {
                    { "MSSQL", selectedProvider.Equals("MSSQL", StringComparison.OrdinalIgnoreCase) },
                    { "NPGSQL", selectedProvider.Equals("NPGSQL", StringComparison.OrdinalIgnoreCase) }
                };
                return Ok(providers);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("UpdateProvider")]
        public IHttpActionResult Update(string Provider)
        {
            try
            {
                if (string.IsNullOrEmpty(Provider))
                    return BadRequest("Provider value is required.");

                
                string configPath = AppDomain.CurrentDomain.BaseDirectory + "web.config";

                
                var config = System.Web.Configuration.WebConfigurationManager.OpenWebConfiguration("~");

                
                config.AppSettings.Settings["DatabaseProvider"].Value = Provider;

                
                config.Save(ConfigurationSaveMode.Modified);

                ConfigurationManager.RefreshSection("appSettings");

                return Ok("Database provider updated successfully.");
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        
    }
}
