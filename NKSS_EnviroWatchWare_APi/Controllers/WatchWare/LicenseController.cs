using Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Web.Http;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    //[Authorize(Roles = "Demo")]
    [RoutePrefix("License")]
    public class LicenseController : ApiController
    {
        private readonly LicenseService license_service;
        private Helpers.Validator validator = new Helpers.Validator();
        public LicenseController(LicenseService _license_service)
        {
            this.license_service = _license_service;
        }


        [HttpGet]
        [Route("GetProductDetails")]
        public IHttpActionResult GetProductDetails(string licenseKey)
        {
            try
            {
                var details = license_service.GetProductSoftwareTrack(licenseKey);
                if (details == null)
                {
                    return NotFound();
                }
                return Ok(details);
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
        [Route("RegisterProduct")]
        public IHttpActionResult RegisterProduct(Models.Licenses.ProductDetails product)
        {
            try
            {
                license_service.RegisterProduct(product);
                return Ok();
            }
            catch(Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetLicenseStatus")]
        public IHttpActionResult GetLicenseStatus()
        {
            try
            {
                var license = license_service.GetLicenseStatus();
                if (license == null)
                {
                    return Ok(false);
                }

                if (license.Active)
                {
                    return Ok(true);
                }
                else
                {
                    return Ok(false);
                }
            }
            catch(Exception ex)
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
