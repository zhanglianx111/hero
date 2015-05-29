/*
Copyright 2014 Google Inc. All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package e2e

import (
	"fmt"
	"io/ioutil"
	"net/http"
	"sort"
	"strings"
	"time"

	"github.com/GoogleCloudPlatform/kubernetes/pkg/api"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/client"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/util"

	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("Services", func() {
	var c *client.Client
	// Use these in tests.  They're unique for each test to prevent name collisions.
	var namespace0, namespace1 string

	BeforeEach(func() {
		var err error
		c, err = loadClient()
		Expect(err).NotTo(HaveOccurred())
		namespace0 = "e2e-ns-" + dateStamp() + "-0"
		namespace1 = "e2e-ns-" + dateStamp() + "-1"
	})

	It("should provide DNS for the cluster", func() {
		if testContext.Provider == "vagrant" {
			By("Skipping test which is broken for vagrant (See https://github.com/GoogleCloudPlatform/kubernetes/issues/3580)")
			return
		}

		podClient := c.Pods(api.NamespaceDefault)

		//TODO: Wait for skyDNS

		// All the names we need to be able to resolve.
		namesToResolve := []string{
			"kubernetes-ro",
			"kubernetes-ro.default",
			"kubernetes-ro.default.kubernetes.local",
			"google.com",
		}

		probeCmd := "for i in `seq 1 600`; do "
		for _, name := range namesToResolve {
			probeCmd += fmt.Sprintf("wget -O /dev/null %s && echo OK > /results/%s;", name, name)
		}
		probeCmd += "sleep 1; done"

		// Run a pod which probes DNS and exposes the results by HTTP.
		By("creating a pod to probe DNS")
		pod := &api.Pod{
			TypeMeta: api.TypeMeta{
				Kind:       "Pod",
				APIVersion: "v1beta1",
			},
			ObjectMeta: api.ObjectMeta{
				Name: "dns-test-" + string(util.NewUUID()),
			},
			Spec: api.PodSpec{
				Volumes: []api.Volume{
					{
						Name: "results",
						VolumeSource: api.VolumeSource{
							EmptyDir: &api.EmptyDirVolumeSource{},
						},
					},
				},
				Containers: []api.Container{
					{
						Name:  "webserver",
						Image: "gcr.io/google_containers/test-webserver",
						VolumeMounts: []api.VolumeMount{
							{
								Name:      "results",
								MountPath: "/results",
							},
						},
					},
					{
						Name:    "pinger",
						Image:   "gcr.io/google_containers/busybox",
						Command: []string{"sh", "-c", probeCmd},
						VolumeMounts: []api.VolumeMount{
							{
								Name:      "results",
								MountPath: "/results",
							},
						},
					},
				},
			},
		}

		By("submitting the pod to kubernetes")
		defer func() {
			By("deleting the pod")
			defer GinkgoRecover()
			podClient.Delete(pod.Name)
		}()
		if _, err := podClient.Create(pod); err != nil {
			Failf("Failed to create %s pod: %v", pod.Name, err)
		}

		expectNoError(waitForPodRunning(c, pod.Name))

		By("retrieving the pod")
		pod, err := podClient.Get(pod.Name)
		if err != nil {
			Failf("Failed to get pod %s: %v", pod.Name, err)
		}

		// Try to find results for each expected name.
		By("looking for the results for each expected name")
		var failed []string
		for try := 1; try < 100; try++ {
			failed = []string{}
			for _, name := range namesToResolve {
				_, err := c.Get().
					Prefix("proxy").
					Resource("pods").
					Namespace(api.NamespaceDefault).
					Name(pod.Name).
					Suffix("results", name).
					Do().Raw()
				if err != nil {
					failed = append(failed, name)
					fmt.Printf("Lookup using %s for %s failed: %v\n", pod.Name, name, err)
				}
			}
			if len(failed) == 0 {
				break
			}
			fmt.Printf("lookups using %s failed for: %v\n", pod.Name, failed)
			time.Sleep(10 * time.Second)
		}
		Expect(len(failed)).To(Equal(0))

		// TODO: probe from the host, too.

		fmt.Printf("DNS probes using %s succeeded\n", pod.Name)
	})

	It("should provide RW and RO services", func() {
		svc := api.ServiceList{}
		err := c.Get().
			AbsPath("/api/v1beta1/proxy/services/kubernetes-ro/api/v1beta1/services").
			Do().
			Into(&svc)
		if err != nil {
			Failf("unexpected error listing services using ro service: %v", err)
		}
		var foundRW, foundRO bool
		for i := range svc.Items {
			if svc.Items[i].Name == "kubernetes" {
				foundRW = true
			}
			if svc.Items[i].Name == "kubernetes-ro" {
				foundRO = true
			}
		}
		Expect(foundRW).To(Equal(true))
		Expect(foundRO).To(Equal(true))
	})

	It("should serve a basic endpoint from pods", func(done Done) {
		serviceName := "endpoint-test2"
		ns := api.NamespaceDefault
		labels := map[string]string{
			"foo": "bar",
			"baz": "blah",
		}

		defer func() {
			err := c.Services(ns).Delete(serviceName)
			Expect(err).NotTo(HaveOccurred())
		}()

		service := &api.Service{
			ObjectMeta: api.ObjectMeta{
				Name: serviceName,
			},
			Spec: api.ServiceSpec{
				Selector: labels,
				Ports: []api.ServicePort{{
					Port:       80,
					TargetPort: util.NewIntOrStringFromInt(80),
				}},
			},
		}
		_, err := c.Services(ns).Create(service)
		Expect(err).NotTo(HaveOccurred())
		expectedPort := 80

		validateEndpointsOrFail(c, ns, serviceName, expectedPort, []string{})

		var names []string
		defer func() {
			for _, name := range names {
				err := c.Pods(ns).Delete(name)
				Expect(err).NotTo(HaveOccurred())
			}
		}()

		name1 := "test1"
		addEndpointPodOrFail(c, ns, name1, labels)
		names = append(names, name1)

		validateEndpointsOrFail(c, ns, serviceName, expectedPort, names)

		name2 := "test2"
		addEndpointPodOrFail(c, ns, name2, labels)
		names = append(names, name2)

		validateEndpointsOrFail(c, ns, serviceName, expectedPort, names)

		err = c.Pods(ns).Delete(name1)
		Expect(err).NotTo(HaveOccurred())
		names = []string{name2}

		validateEndpointsOrFail(c, ns, serviceName, expectedPort, names)

		err = c.Pods(ns).Delete(name2)
		Expect(err).NotTo(HaveOccurred())
		names = []string{}

		validateEndpointsOrFail(c, ns, serviceName, expectedPort, names)

		// We deferred Gingko pieces that may Fail, we aren't done.
		defer func() {
			close(done)
		}()
	}, 240.0)

	It("should be able to create a functioning external load balancer", func() {
		serviceName := "external-lb-test"
		ns := api.NamespaceDefault
		labels := map[string]string{
			"key0": "value0",
		}
		service := &api.Service{
			ObjectMeta: api.ObjectMeta{
				Name: serviceName,
			},
			Spec: api.ServiceSpec{
				Selector: labels,
				Ports: []api.ServicePort{{
					Port:       80,
					TargetPort: util.NewIntOrStringFromInt(80),
				}},
				CreateExternalLoadBalancer: true,
			},
		}

		By("cleaning up previous service " + serviceName + " from namespace " + ns)
		c.Services(ns).Delete(serviceName)

		By("creating service " + serviceName + " with external load balancer in namespace " + ns)
		result, err := c.Services(ns).Create(service)
		Expect(err).NotTo(HaveOccurred())
		defer func(ns, serviceName string) { // clean up when we're done
			By("deleting service " + serviceName + " in namespace " + ns)
			err := c.Services(ns).Delete(serviceName)
			Expect(err).NotTo(HaveOccurred())
		}(ns, serviceName)

		if len(result.Spec.PublicIPs) != 1 {
			Failf("got unexpected number (%d) of public IPs for externally load balanced service: %v", result.Spec.PublicIPs, result)
		}
		ip := result.Spec.PublicIPs[0]
		port := result.Spec.Ports[0].Port

		pod := &api.Pod{
			TypeMeta: api.TypeMeta{
				Kind:       "Pod",
				APIVersion: "v1beta1",
			},
			ObjectMeta: api.ObjectMeta{
				Name:   "elb-test-" + string(util.NewUUID()),
				Labels: labels,
			},
			Spec: api.PodSpec{
				Containers: []api.Container{
					{
						Name:  "webserver",
						Image: "gcr.io/google_containers/test-webserver",
					},
				},
			},
		}

		By("creating pod to be part of service " + serviceName)
		podClient := c.Pods(api.NamespaceDefault)
		defer func() {
			By("deleting pod " + pod.Name)
			defer GinkgoRecover()
			podClient.Delete(pod.Name)
		}()
		if _, err := podClient.Create(pod); err != nil {
			Failf("Failed to create pod %s: %v", pod.Name, err)
		}
		expectNoError(waitForPodRunning(c, pod.Name))

		By("hitting the pod through the service's external load balancer")
		var resp *http.Response
		for t := time.Now(); time.Since(t) < 4*time.Minute; time.Sleep(5 * time.Second) {
			resp, err = http.Get(fmt.Sprintf("http://%s:%d", ip, port))
			if err == nil {
				break
			}
		}
		Expect(err).NotTo(HaveOccurred())
		defer resp.Body.Close()

		body, err := ioutil.ReadAll(resp.Body)
		Expect(err).NotTo(HaveOccurred())
		if resp.StatusCode != 200 {
			Failf("received non-success return status %q trying to access pod through load balancer; got body: %s", resp.Status, string(body))
		}
		if !strings.Contains(string(body), "test-webserver") {
			Failf("received response body without expected substring 'test-webserver': %s", string(body))
		}
	})

	It("should correctly serve identically named services in different namespaces on different external IP addresses", func() {
		serviceNames := []string{"s0"}                 // Could add more here, but then it takes longer.
		namespaces := []string{namespace0, namespace1} // As above.
		labels := map[string]string{
			"key0": "value0",
			"key1": "value1",
		}
		service := &api.Service{
			ObjectMeta: api.ObjectMeta{},
			Spec: api.ServiceSpec{
				Selector: labels,
				Ports: []api.ServicePort{{
					Port:       80,
					TargetPort: util.NewIntOrStringFromInt(80),
				}},
				CreateExternalLoadBalancer: true,
			},
		}

		publicIPs := []string{}
		for _, namespace := range namespaces {
			for _, serviceName := range serviceNames {
				service.ObjectMeta.Name = serviceName
				service.ObjectMeta.Namespace = namespace
				By("creating service " + serviceName + " in namespace " + namespace)
				result, err := c.Services(namespace).Create(service)
				Expect(err).NotTo(HaveOccurred())
				defer func(namespace, serviceName string) { // clean up when we're done
					By("deleting service " + serviceName + " in namespace " + namespace)
					err := c.Services(namespace).Delete(serviceName)
					Expect(err).NotTo(HaveOccurred())
				}(namespace, serviceName)
				publicIPs = append(publicIPs, result.Spec.PublicIPs...) // Save 'em to check uniqueness
			}
		}
		validateUniqueOrFail(publicIPs)
	})
})

func validateUniqueOrFail(s []string) {
	By(fmt.Sprintf("validating unique: %v", s))
	sort.Strings(s)
	var prev string
	for i, elem := range s {
		if i > 0 && elem == prev {
			Fail("duplicate found: " + elem)
		}
		prev = elem
	}
}

func flattenSubsets(subsets []api.EndpointSubset, expectedPort int) util.StringSet {
	ips := util.StringSet{}
	for _, ss := range subsets {
		for _, port := range ss.Ports {
			if port.Port == expectedPort {
				for _, addr := range ss.Addresses {
					ips.Insert(addr.IP)
				}
			}
		}
	}
	return ips
}

func validateIPsOrFail(c *client.Client, ns string, expectedPods []string, ips util.StringSet) {
	for _, name := range expectedPods {
		pod, err := c.Pods(ns).Get(name)
		if err != nil {
			Failf("failed to get pod %s, that's pretty weird. validation failed: %s", name, err)
		}
		if !ips.Has(pod.Status.PodIP) {
			Failf("ip validation failed, expected: %v, saw: %v", ips, pod.Status.PodIP)
		}
		By(fmt.Sprintf(""))
	}
	By(fmt.Sprintf("successfully validated IPs %v against expected endpoints %v on namespace %s", ips, expectedPods, ns))
}

func validateEndpointsOrFail(c *client.Client, ns, serviceName string, expectedPort int, expectedPods []string) {
	for {
		endpoints, err := c.Endpoints(ns).Get(serviceName)
		if err == nil {
			ips := flattenSubsets(endpoints.Subsets, expectedPort)
			if len(ips) == len(expectedPods) {
				validateIPsOrFail(c, ns, expectedPods, ips)
				break
			} else {
				By(fmt.Sprintf("Unexpected number of endpoints: found %v, expected %v (ignoring for 1 second)", ips, expectedPods))
			}
		} else {
			By(fmt.Sprintf("Failed to get endpoints: %v (ignoring for 1 second)", err))
		}
		time.Sleep(time.Second)
	}
	By(fmt.Sprintf("successfully validated endpoints %v port %d on service %s/%s", expectedPods, expectedPort, ns, serviceName))
}

func addEndpointPodOrFail(c *client.Client, ns, name string, labels map[string]string) {
	By(fmt.Sprintf("Adding pod %v in namespace %v", name, ns))
	pod := &api.Pod{
		ObjectMeta: api.ObjectMeta{
			Name:   name,
			Labels: labels,
		},
		Spec: api.PodSpec{
			Containers: []api.Container{
				{
					Name:  "test",
					Image: "gcr.io/google_containers/pause",
					Ports: []api.ContainerPort{{ContainerPort: 80}},
				},
			},
		},
	}
	_, err := c.Pods(ns).Create(pod)
	Expect(err).NotTo(HaveOccurred())
}

// dateStamp returns the current time as a string "YYYY-MM-DDTHHMMSS"
// Handy for unique names across test runs
func dateStamp() string {
	now := time.Now()
	return fmt.Sprintf("%04d-%02d-%02dt%02d%02d%02d", now.Year(), now.Month(), now.Day(), now.Hour(), now.Minute(), now.Second())
}
