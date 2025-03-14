using Models.PollutionData;
using NKSS_EnviroWatchWare_APi.Providers;
using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [PollutantAuthorize]    
    [RoutePrefix("PollutantData")]
    public class PollutantDataController : ApiController
    {
        private readonly PollutionDataService pollutionDataService;
        public PollutantDataController(PollutionDataService _pollutionDataService)
        {
            pollutionDataService = _pollutionDataService;
        }
        [HttpPost]
        [Route("Upload")]
        public IHttpActionResult Upload(PollutantDataUploadRequest Request)
        {            
            try
            {
                string authHeader = HttpContext.Current.Request.Headers["Authorization"];                
                bool success = pollutionDataService.ImportData(authHeader,Request);
                if (success)
                {
                    return Ok("Data inserted successfully.");
                }
                else
                {
                    return BadRequest("Insertion failed.");
                }                
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("UploadBulk")]
        public IHttpActionResult UploadBulk()
        {
            try
            {
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }        
    }
}
